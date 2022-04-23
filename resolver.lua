local errors = require("errors")
local enums = require("enums")

local ParamType = enums.ParamType
local ParsedType = enums.ParsedType
local ResolvedType = enums.ResolvedType

local TYPE_NAMES = {
	[ParamType.any] = "any",
	[ParamType.string] = "string",
	[ParamType.none] = "nil value",
	[ParamType.number] = "number",
	[ParamType.pointer] = "pointer",
}

local MUST_RESOLVE_TO = "must resolve to a %s (resolved to %q)"
local UNDEFINED_MACRO = "undefined macro %q"
local MAY_NOT_BE_FIRST = "back retrieval may not be the first argument"
local TOO_FEW_ARGS = "expects at least %d arguments (got %d)"
local TOO_MANY_ARGS = "expects at most %d arguments (got %d)"
local REGISTER_DESTINATION = "register destination: %s"
local CANNOT_ACCESS_REGISTERS = "cannot access registers"
local REGISTER_OUT_OF_BOUNDS = "register %d is out of bounds"
local REGISTER_MUST_RESOLVE_TO = "previous register value must resolve to a %s (resolved to %q)"



local function unpackArg(arg)
	return table.unpack(arg, 1, 2)
end



local function isAny()
	return true
end

local function isNil(value)
	return value == nil
end

local function isString(value)
	return value ~= nil
end

local function isNumber(value)
	return type(value) == "number"
end

local function isPointer(value)
	return isNumber(value) and value % 1 == 0 and value > 0
end

local checkers = {
	[ParamType.any] = isAny,
	[ParamType.string] = isString,
	[ParamType.none] = isNil,
	[ParamType.number] = isNumber,
	[ParamType.pointer] = isPointer,
}
local function checkValue(value, paramCode)
	local checker = checkers[paramCode]
	if not checker then error("invalid param code: " .. tostring(paramCode)) end

	local success = checker(value)
	if success then
		return true, value -- Value may be nil, cannot use inlined if
	else
		return false, MUST_RESOLVE_TO:format(TYPE_NAMES[paramCode], value)
	end
end

local function resolveIdentifierValue(nameValue, paramCode, state)
	if paramCode == ParamType.identifier then
		return true, nameValue
	end

	local value = state.macros[nameValue]

	if value or state.nilmacros[value] then
		return checkValue(value, paramCode)
	else
		return false, UNDEFINED_MACRO:format(nameValue)
	end
end



--[[--
	Passes varargs through a resolver which is expected to return a success, res
	tuple. On success, res is returned inside a ResolvedType.value structure.
	Otherwise, a nil, err tuple is returned.
]]
local function makeValue(resolver, ...)
	local success, res = resolver(...)
	if success then
		return {ResolvedType.value, res}, nil
	else
		return nil, res
	end
end

--- Resolves a literal value and returns it in a ResolvedType.value structure
local function resolveLiteral(value, paramCode)
	return makeValue(checkValue, value, paramCode)
end

--- Resolves an identifier value and returns it in a ResolvedType.value structure
local function resolveIdentifier(value, paramCode, state)
	return makeValue(resolveIdentifierValue, value, paramCode, state)
end



local function makeRetrieval(value, depth, paramCode)
	return {ResolvedType.retrieval, value, depth, paramCode}
end

--- Resolves the value fields of a retrieval argument
local function resolveRetrieval(value, depth, paramCode, state)
	local subType, subValue = unpackArg(value)
	local resolver = (subType == ParsedType.literal) and checkValue or resolveIdentifierValue

	local success, res = resolver(subValue, ParamType.pointer, state)
	if success then
		return makeRetrieval(res, depth, paramCode), nil
	else
		return nil, REGISTER_DESTINATION:format(res)
	end
end

--- Resolves the back retrieval to either be a retrieval of a literal or a
--- deeper retrieval than the first arg
local function resolveBackRetrieval(paramCode, firstArg)
	if not firstArg then
		return nil, MAY_NOT_BE_FIRST
	end

	local firstType, firstValue = unpackArg(firstArg)

	local depth = 1
	if firstType == ResolvedType.value then
		local success, err = checkValue(firstValue, ParamType.pointer)

		if not success then
			return nil, err
		end
	else
		depth = firstArg[3] + 1
	end

	return makeRetrieval(firstValue, depth, paramCode), nil
end


--- Calls the appropriate resolution function
local function resolveArgument(arg, paramCode, state, firstArg)
	local argType, argValue = unpackArg(arg)

	if argType == ParsedType.literal then
		return resolveLiteral(argValue, paramCode)

	elseif argType == ParsedType.identifier then
		return resolveIdentifier(argValue, paramCode, state)

	elseif argType == ParsedType.retrieval then
		return resolveRetrieval(argValue, arg[3], paramCode, state)

	elseif argType == ParsedType.backRetrieval then
		return resolveBackRetrieval(paramCode, firstArg)

	else
		error("invalid arg type: " .. tostring(argType))
	end
end

--[[--
	Takes an array of ParsedArg structures and a ParamString as well as a
	ParseState, which it then transforms into an array of ResolvedArg
	structures.
]]
local function resolveArgs(args, paramsStr, state)
	local resolvedArgs = {}
	local first = nil

	local startIndex = 1
	for paramCode, isVararg in string.gmatch(paramsStr, "(%a)(+?)") do
		-- Consume args up to a specific position (all the way if varargs)
		local consumeUpTo = (isVararg ~= "" and #args or startIndex)

		for i = startIndex, consumeUpTo do
			-- No arg means that there are fewer arguments than there should be
			local arg = args[i]
			if not arg then
				local minParams = select(2, string.gsub(paramsStr, "%a", ""))

				return nil, TOO_FEW_ARGS:format(minParams, i - 1)
			end

			-- Resolve
			local newArg, err = resolveArgument(arg, paramCode, state, first)
			if not newArg then
				return nil, errors.formatArg(i, err)
			end
			resolvedArgs[i] = newArg

			-- Update the first argument
			if i == 1 then
				first = newArg
			end
		end

		startIndex = consumeUpTo + 1
	end

	-- Check for too many args
	if #args > startIndex then
		return nil, TOO_MANY_ARGS:format(startIndex, #args)
	end

	return resolvedArgs, nil
end




--[[--
	Takes registers, a starting name and a depth, sequentially performs
	retrievals, making sure the intermediate and resulting values are correct.
]]
local function expandRetrieval(value, depth, expectedFinal, registers)
	if not registers then
		return false, CANNOT_ACCESS_REGISTERS
	end

	local trace = {}

	for i = 1, depth do
		trace[i] = value

		if not isPointer(value) then
			return false, errors.errWithTrace(REGISTER_MUST_RESOLVE_TO, trace, TYPE_NAMES[ParamType.pointer], value)
		end

		local num = tonumber(value)
		if num > registers.n then
			return false, errors.errWithTrace(REGISTER_OUT_OF_BOUNDS, trace, num)
		end

		value = registers[num]
	end

	local success, err = checkValue(value, expectedFinal)
	if success then
		return true, value
	else
		return false, errors.errWithTrace(err, trace)
	end
end

local function expandArgs(args, registers)
	local new = {n = #args}

	for i, arg in ipairs(args) do
		if arg[1] == ResolvedType.value then
			new[i] = arg[2]
		else
			local success, res = expandRetrieval(arg[2], arg[3], arg[4], registers)
			if success then
				new[i] = res
			else
				return nil, errors.formatArg(i, res)
			end
		end
	end

	return new, nil
end



return {
	resolveArgs = resolveArgs,
	expandArgs = expandArgs,
}