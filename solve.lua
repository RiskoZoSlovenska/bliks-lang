--[[= [standalone] fn solve
	Takes parsed instructions and a set of Functions, and validifies and
	resolves the parsed instructions into executable ones. This involves
	verifying known types, running compile-time functions and expanding macros,
	amongst other things.

	@param {{Token}} parsed
	@param {string:Function} funcs

	@return CompiledProgram
]]

--[[= struct CompiledProgram
	- {Instruction} instructions
	- integer begin

	@compound string any
]]

local types = require("types")
local enums = require("enums")
local structs = require("structs")
local utils = require("utils")
local expandArgs = require("expand")

local TokenType = enums.TokenType
local ValueType = enums.ValueType
local ArgumentType = enums.ArgumentType

local Error = structs.Error
local Token = structs.Token
local Argument = structs.Argument
local Instruction = structs.Instruction

local DEFAULT_MACROS = {
	pi = math.pi,
	e = math.exp(1),
	inf = math.huge,
	ninf = -math.huge,
	["true"] = "true",
	["false"] = "",
	_1 = 1,
	_2 = 2,
	_3 = 3,
	_4 = 4,
}

local function copy(tbl)
	local copied = {}

	for k, v in pairs(tbl) do
		copied[k] = type(v) == "table" and copy(v) or v
	end

	return copied
end

local function tokensOfType(tokens, typ)
	local i, len = 0, #tokens
	return function()
		repeat
			i = i + 1
		until i > len or tokens[i].type == typ

		return i <= len and i or nil, tokens[i]
	end
end

local function getParamTypeAtIndex(params, index)
	return params[math.min(index, #params)]
end


local function checkArgCounts(tokens, func, funcPos)
	local params = func.params
	local numArgs = #tokens
	if numArgs < params.min then
		return Error("function expects at least %d argument(s), but got only %d", funcPos, params.min, numArgs)
	elseif numArgs > params.max then
		return Error("function expects at most %d argument(s), but got %d", funcPos, params.max, numArgs)
	end

	return nil
end

--[[
	Performs an in-place replacement of all back retrieval tokens with normal
	retrieval tokens. Modifies the `tokens` table, but leaves all sub-tables
	unmodified. Returns nil on success, or an error on error.
]]
local function expandBackRetrievals(tokens)
	local firstToken = tokens[1]
	if not firstToken then
		return nil
	elseif firstToken.type == TokenType.backRetrieval then
		return Error("the first argument cannot be a back retrieval", firstToken.pos)
	end
	local firstIsRetrieval = (firstToken.type == TokenType.retrieval)

	for i, token in tokensOfType(tokens, TokenType.backRetrieval) do
		local baseToken = firstIsRetrieval and firstToken.value or firstToken

		tokens[i] = Token(
			TokenType.retrieval,
			Token(baseToken.type, baseToken.value, nil, token.pos),
			(firstToken.depth or 0) + 1,
			token.pos
		)
	end

	return nil
end

local function expandMacro(token, acc)
	local value = acc.macros[token.value]
	if value == nil then
		return nil, Error("macro '%s' is not defined", token.pos, token.value)
	end

	return Token(TokenType.literal, value, nil, token.pos), nil
end

local function expandMacros(tokens, func, acc)
	-- Surface-level names
	for i, token in tokensOfType(tokens, TokenType.name) do
		local paramType = getParamTypeAtIndex(func.params, i)

		if paramType ~= ValueType.name then -- Don't expand non-macro names
			local newToken, err = expandMacro(token, acc)
			if not newToken then
				return err
			end

			tokens[i] = newToken
		end
	end

	-- Names in retrievals
	for _, token in tokensOfType(tokens, TokenType.retrieval) do
		if token.value.type == TokenType.name then
			local newToken, err = expandMacro(token.value, acc)
			if not newToken then
				return err
			end

			token.value = newToken
		end
	end

	return nil
end

local function typecheckRetrievals(tokens, func)
	for i, token in tokensOfType(tokens, TokenType.retrieval) do
		local actualType = types.typeoftoken(token.value)
		if not types.is(actualType, ValueType.pointer) then
			return Error(
				"retrieval (for argument %d) expects a %s, but got '%s' (a %s)",
				token.value.pos, i, ValueType.pointer, utils.truncate(token.value.value), actualType
			)
		end

		local paramType = getParamTypeAtIndex(func.params, i)
		if paramType == ValueType.name then
			return Error("function expects a %s for argument %d, but got a retrieval", token.pos, ValueType.name, i)
		end
	end

	return nil
end

local function typecheckLiterals(tokens, func)
	for i, token in tokensOfType(tokens, TokenType.literal) do
		local paramType = getParamTypeAtIndex(func.params, i)

		local actualType = types.typeoftoken(token)
		if not types.is(actualType, paramType) then
			return Error(
				"function expects a %s for argument %d, but got '%s' (a %s)",
				token.pos, paramType, i, utils.truncate(token.value), actualType
			)
		end
	end

	return nil
end

local function convertArguments(tokens, func)
	local args = {}

	for i, token in ipairs(tokens) do
		local paramType = getParamTypeAtIndex(func.params, i)

		if token.type ~= TokenType.retrieval then
			args[i] = Argument(ArgumentType.value, paramType, token.value, nil, token.pos)
		elseif func.params.static[i] then
			return nil, Error("argument %d cannot be a retrieval", token.pos, i)
		else
			args[i] = Argument(ArgumentType.retrieval, paramType, token.value.value, token.depth, token.pos)
		end
	end

	return args, nil
end


return function(parsed, stdlib)
	local program = {
		instructions = {},
		macros = copy(DEFAULT_MACROS), -- Temporary, will be removed at the end
		curInstruction = 1, -- Temporary and read-only
		begin = nil,
	}

	for _, tokens in ipairs(copy(parsed)) do
		-- Get function token
		local funcToken = assert(table.remove(tokens, 1))
		if funcToken.type ~= TokenType.name then
			return nil, Error("expected instruction name, got a %s", funcToken.pos, funcToken.type)
		end

		-- Get function
		local func = stdlib[funcToken.value]
		if not func then
			return nil, Error("no such function '%s'", funcToken.pos, funcToken.value)
		end

		local countsErr = checkArgCounts(tokens, func, funcToken.pos)
		if countsErr then
			return nil, countsErr
		end

		local expandErr = expandBackRetrievals(tokens)
		if expandErr then
			return nil, expandErr
		end

		local macroErr = expandMacros(tokens, func, program)
		if macroErr then
			return nil, macroErr
		end

		local retrievalsErr = typecheckRetrievals(tokens, func)
		if retrievalsErr then
			return nil, retrievalsErr
		end

		local literalsErr = typecheckLiterals(tokens, func)
		if literalsErr then
			return nil, literalsErr
		end

		local args, argsErr = convertArguments(tokens, func)
		if not args then
			return nil, argsErr
		end

		if func.compileFunc then
			program.curInstruction = #program.instructions + 1
			local err = func.compileFunc(program, table.unpack(assert(expandArgs(args, nil))))
			if err then
				return nil, Error(err, funcToken.pos)
			end
		end
		if func.runFunc then
			table.insert(program.instructions, Instruction(funcToken.value, args, #program.instructions + 1, funcToken.pos))
		end
	end

	program.begin = program.begin or 1
	program.macros = nil
	program.curInstruction = nil

	return program
end
