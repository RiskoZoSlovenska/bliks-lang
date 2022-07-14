--[[
	Takes raw tokens and outputs a Program.

	Program
	  instructions {Instruction}
	  custom {any:any}

	Instruction
	  lineNum int
	  run callable
	  args {Argument}

	Argument
	  [1] "value"|"retrieval"
	  [2] any|string
]]

local enums = require("./enums")

local TokenType = enums.TokenType
local ValueType = enums.ValueType
local ArgumentType = enums.ArgumentType

local PARAM_TYPE_ALIASES = {
	i = ValueType.identifier,
	a = ValueType.any,
	s = ValueType.string,
	n = ValueType.number,
	p = ValueType.pointer,
}

local IS_A = {
	[ValueType.identifier] = {
		[ValueType.identifier] = true,
	},

	[ValueType.any] = {
		[ValueType.any] = true,
	},
	[ValueType.string] = {
		[ValueType.any] = true,
		[ValueType.string] = true,
	},
	[ValueType.number] = {
		[ValueType.any] = true,
		[ValueType.string] = true,
		[ValueType.number] = true,
	},
	[ValueType.pointer] = {
		[ValueType.any] = true,
		[ValueType.string] = true,
		[ValueType.number] = true,
		[ValueType.pointer] = true,
	},
}

local function Value(value)
	return { ArgumentType.value, value }
end

local function Retrieval(number, depth, expected)
	return { ArgumentType.retrieval, number, depth, expected }
end

local function BackRetrieval(first, expected)
	if first[1] == ArgumentType.value then
		return Retrieval(first[2], 1, expected)
	else
		return Retrieval(first[2], first[3] + 1, expected)
	end
end



local function getValueType(value)
	local asNumber = tonumber(value)

	if asNumber and asNumber > 0 and asNumber % 1 == 0 then
		return ValueType.pointer
	elseif asNumber then
		return ValueType.number
	elseif value then
		return ValueType.string
	else
		return ValueType.any
	end
end

local function checkValueType(value, expected)
	local actual = getValueType(value)

	if IS_A[actual][expected] then
		return true, actual
	else
		return false, actual
	end
end

local function getParamType(symbol)
	if not symbol then
		return nil
	else
		return assert(PARAM_TYPE_ALIASES[symbol], "invalid param type")
	end
end

local function parseParamsString(str)
	local parsed = {
		minCount  = 0,
		maxCount = nil,
		varargs = nil,
	}

	for param in string.gmatch(str, "%a") do
		local t = getParamType(param)
		table.insert(parsed, t)
		parsed.minCount = parsed.minCount + 1
	end

	parsed.varargs = getParamType(str:match("(%a)%+$"))
	parsed.maxCount = parsed.varargs and math.huge or parsed.minCount

	return parsed
end



local function handleValue(value, expected)
	local correct, actual = checkValueType(value, expected)

	if correct then
		return Value(IS_A[actual][ValueType.number] and tonumber(value) or value), nil
	else
		return nil, string.format("expected %s, got %s", expected, actual)
	end
end

local function handleLiteral(token, expected, first, program)
	return handleValue(token[2], expected)
end

local function handleIdentifier(identifierToken, expected, first, program)
	local name = identifierToken[2]

	if expected == ValueType.identifier then
		return Value(name), nil
	else
		if program.macros[name] or program.nilmacros[name] then
			return handleValue(program.macros[name], expected)
		else
			return nil, "undefined macro"
		end
	end
end

local function handleRetrieval(retrievalToken, expected, first, program)
	if expected == ValueType.identifier then
		return nil, "retrieval cannot resolve to an identifier"
	end

	local startToken = retrievalToken[2]
	local handler = (startToken[1] == TokenType.identifier) and handleIdentifier or handleLiteral

	local value, err = handler(startToken, ValueType.pointer, first, program)
	if not value then
		return nil, err
	else
		return Retrieval(value[2], retrievalToken[3], expected), nil
	end
end

local function handleBackRetrieval(token, expected, first, program)
	if not first then
		return nil, "first argument must not be a back retrieval"
	end

	return BackRetrieval(first, expected)
end

local argHandlers = {
	[TokenType.literal] = handleLiteral,
	[TokenType.identifier] = handleIdentifier,
	[TokenType.retrieval] = handleRetrieval,
	[TokenType.back_retrieval] = handleBackRetrieval,
}

local function resolveArgs(tokens, params, program)
	local numArgs = #tokens - 1

	if numArgs < params.minCount then
		return nil, string.format("function expects at least %d argument(s), but got %d", params.minCount, numArgs)
	elseif numArgs > params.maxCount then
		return nil, string.format("function expects at most %d argument(s), but got %d", params.maxCount, numArgs)
	end

	local firstArg = nil
	local resolved = {}

	for i = 1, numArgs do
		local token = tokens[i + 1]
		local handler = argHandlers[token[1]]
		local expected = assert(params[i] or params.varargs)

		local value, err = handler(token, expected, firstArg, program)
		if not value then
			return nil, err
		else
			table.insert(resolved, value)
		end

		if not firstArg then
			firstArg = value
		end
	end

	return resolved
end


local function runCTFunction(run, args, program)
	local rawArgs = {program}

	for i, arg in ipairs(args) do
		if arg[1] == ArgumentType.retrieval then
			return "compile-time functions cannot use retrievals"
		else
			rawArgs[i + 1] = arg[2]
		end
	end

	local success, err = pcall(run, table.unpack(rawArgs, 1, #args + 1))
	if not success then
		error("compile-time function threw an error: " .. err)
	elseif err then
		return err
	else
		return nil
	end
end

local function resolveLine(tokens, program, options)
	local funcToken = assert(tokens[1], "empty line")
	if funcToken[1] ~= TokenType.identifier then
		return nil, "instruction must start with a function name"
	end

	local funcName = funcToken[2]
	local ctFuncInfo = options.compileTimeFunctions[funcName]
	local rtFuncInfo = options.runTimeFunctions[funcName]
	local funcInfo = ctFuncInfo or rtFuncInfo

	if not funcInfo then
		return nil, "unknown function name"
	end

	local funcParams = parseParamsString(funcInfo[1])
	local args, err = resolveArgs(tokens, funcParams, program)
	if not args then
		return nil, err
	end

	if ctFuncInfo then
		local runErr = runCTFunction(ctFuncInfo[2], args, program)
		return nil, runErr or nil
	else
		return {
			args = args,
			run = rtFuncInfo[3],
		}, nil
	end
end

local function resolve(lines, options)
	local program = {
		instructions = {},
		firstInstruction = nil,

		labels = {},

		macros = {},
		nilmacros = {},
	}

	for _, line in ipairs(lines) do
		local instruction, err = resolveLine(line, program, options)
		if err then
			return nil, err
		elseif instruction then
			instruction.lineNum = line.lineNum
			table.insert(program.instructions, instruction)
		end
	end

	if not program.firstInstruction then
		program.firstInstruction = 1
	end

	-- Cleanup
	program.macros = nil
	program.nilmacros = nil

	return program
end



return {
	Value = Value,
	Retrieval = Retrieval,
	BackRetrieval = BackRetrieval,

	resolve = resolve,
}