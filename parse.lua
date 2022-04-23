local lpeg = require("lpeg")

local resolver = require("resolver")
local errors = require("errors")
local enums = require("enums")

local ParsedType = enums.ParsedType

local COMMENT = "#"
local RETRIEVAL = "@"
local BACK_RETRIEVAL = "<"

local BAD_NUMBER = "malformed number"
local BAD_STRING = "unterminated string"
local BAD_REGISTER_REFERENCE = "retrieval destination must be an identifier, a number literal, or a retrieval"
local UNEXPECTED = "unexpected symbol"
local INVALID_KEYWORD = "invalid keyword %q"
local NO_BEGINNING = "program has no beginning"



local function unescape(str)
	return (string.gsub(str, "&(.)", {
		a = "&",
		q = "\"",
		s = ";",
	}))
end



local parseArgs do

	local P, S, R = lpeg.P, lpeg.S, lpeg.R
	local Ct, Cc, Carg, Cmt = lpeg.Ct, lpeg.Cc, lpeg.Carg, lpeg.Cmt
	local locale = lpeg.locale()


	-- These two were taken from https://github.com/LuaDist/dkjson/blob/e72ba0c9f5d8b8746fc306f6189a819dbb5cd0be/dkjson.lua#L610
	local function errCall(str, pos, msg, errState)
		if not errState.msg then
			errState.msg = msg
			errState.pos = pos
		end

		return false
	end

	local function throw(msg)
		return Cmt(Cc(msg) * Carg(1), errCall) * P(false) -- Explicitly tell Lpeg that this pattern always fails
	end


	local function reverseCaptures(a, b)
		return b, a
	end

	local function structure(name)
		return function(...)
			return {name, ...}
		end
	end


	local alnum = R"az" + R"AZ" + R"09" + P"_"
	local space = locale.space


	local identifier = alnum^1 / structure(ParsedType.identifier)


	local literalStructure = structure(ParsedType.literal)

	local stringQuote = P'"'
	local stringBody = (1 - stringQuote)^0 / unescape / literalStructure
	local stringLiteral = stringQuote * stringBody * (stringQuote + throw(BAD_STRING))

	local nilLiteral = P"nil" * Cc(nil) / literalStructure

	local sign = S"+-"^-1
	local digits = R"09"^1
	local decimal = P"."
	local e = S"eE"
	local decimalPart = decimal * (digits + throw(BAD_NUMBER))
	local exponentPart = e * sign * (digits + throw(BAD_NUMBER))
	local numberLiteral = sign * digits * decimalPart^-1 * exponentPart^-1 / tonumber / literalStructure

	local literal = stringLiteral + nilLiteral + numberLiteral


	local retrievalHead = P(RETRIEVAL)^1 / string.len
	local registerReference = numberLiteral + identifier + throw(BAD_REGISTER_REFERENCE)
	local retrieval = retrievalHead * registerReference / reverseCaptures / structure(ParsedType.retrieval)

	local backRetrieval = P(BACK_RETRIEVAL) / 0 / structure(ParsedType.backRetrieval)


	local comment = P(COMMENT) * P(1)^1
	local eol = space^0 * comment^-1 * P(-1)


	local mandatorySpace = space^1 + throw(UNEXPECTED)
	local argument = literal + retrieval + backRetrieval + identifier
	local arguments = Ct(argument^-1 * (mandatorySpace * argument)^0) * eol


	--[[--
		Takes a string and parses a list of values from it. The string is
		assumed to have all leading whitespace trimmed. If successful, it
		returns an array of structures which have the following fields:
			[1] - type - ParsedType
			[2] - value - a nil/string, or for the ParsedType.retrieval type,
				another structure that is either of ParsedType.retrieval or
				ParsedType.retrieval type
			[3] - depth - (ParsedType.retrieval only) the depth of the retrieval
	]]
	function parseArgs(str, strOffset)
		local errState = {}
		local parsed = arguments:match(str, 1, errState)

		if parsed then
			return parsed, nil
		else
			return nil, errors.formatColumn(strOffset + errState.pos, errState.msg)
		end
	end
end



local function doCtFunction(state, funcInfo, args)
	local expanded, expansionErr = resolver.expandArgs(args, nil)
	if not expanded then
		return false, expansionErr
	end

	return funcInfo[2](state, table.unpack(expanded, 1, expanded.n))
end

local function buildInstruction(state, funcInfo, args, funcName)
	-- Compile instruction table
	local func = funcInfo[3]
	local instruction = {func, args, funcName, state.lineNum}
	table.insert(state.instructions, instruction)

	local instructionNum = #state.instructions

	-- Close open labels
	for name in pairs(state.openLabels) do
		if not state.labels[name] then
			state.labels[name] = {}
		end
		table.insert(state.labels[name], instructionNum)
	end
	state.openLabels = {}

	-- Close open first instruction
	if state.openFirstInstruction then
		state.firstInstruction = instructionNum
		state.openFirstInstruction = nil
	end

	return true
end


local function parseLine(state, line)
	-- Skip empty or comment-only lines
	if not line:find("%S") or line:find("^%s*" .. COMMENT) then return true, nil, nil end


	-- Find keyword
	local keywordPos, keyword, argsPos, argsStr = line:match("^%s*()(%S+)%s*()(.*)") -- Must succeed

	local ctFuncInfo = state.ctFunctions[keyword]
	local rtFuncInfo = state.rtFunctions[keyword]
	local funcInfo = ctFuncInfo or rtFuncInfo

	if not funcInfo then
		return nil, errors.formatColumn(keywordPos, INVALID_KEYWORD, keyword)
	end


	-- Parse args
	local args, parseErr = parseArgs(argsStr, argsPos)
	if not args then
		return nil, parseErr
	end


	-- Resolve args
	local paramsString = funcInfo[1]
	local resolvedArgs, argsErr = resolver.resolveArgs(args, paramsString, state)
	if not resolvedArgs then
		return nil, errors.formatFuncName(keyword, argsErr)
	end


	-- Delegate
	if ctFuncInfo then
		local success, err = doCtFunction(state, funcInfo, resolvedArgs)
		return success, err and errors.formatFuncName(keyword, err)
	else
		return buildInstruction(state, funcInfo, resolvedArgs, keyword)
	end
end


local function parse(source, options)
	local state = {
		ctFunctions = options.ctFunctions,
		rtFunctions = options.rtFunctions,

		macros = {},
		nilmacros = {},

		openLabels = {},
		labels = {},

		instructions = {},
		firstInstruction = nil,
		lineNum = 1,
	}

	for line in string.gmatch(source, "([^\r\n]*)\r?\n?") do
		local success, err = parseLine(state, line)
		if not success then
			return nil, errors.formatLine(state.lineNum, err)
		end

		state.lineNum = state.lineNum + 1
	end

	if not state.firstInstruction then
		return nil, NO_BEGINNING
	end

	return state, nil
end



return parse