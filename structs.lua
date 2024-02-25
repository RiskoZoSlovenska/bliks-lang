--[[= struct Error
	- string message
	- integer pos
]]
local function Error(message, pos, ...)
	return {
		message = select("#", ...) > 0 and string.format(message, ...) or message,
		pos = assert(pos),
	}
end

--[[= struct Token
	- TokenType type
	- any value
	- any? depth
	- integer pos
]]
local function Token(typ, value, depth, pos)
	return {
		type = typ,
		value = value,
		depth = depth,
		pos = assert(pos),
	}
end

--[[= struct Parameter
	- ValueType typ The type of value that this parameter expects.
	- boolean isFixed Whether this parameter requires values at compile-time.
]]
local function Parameter(typ, isFixed)
	return {
		type = typ,
		fixed = isFixed,
	}
end

--[[= struct ParameterList
	- integer min The minimum number of arguments that can be passed to this
	  list.
	- integer max The maximum number of arguments that can be passed to this
	  list.
	@compound integer Parameter The parameters in this list.
]]

--[[= struct Argument
	- ArgumentType argType
	- ValueType expectedType
	- any value
	- integer? depth
	- integer pos Starting position of the param token in the source.
]]
local function Argument(argType, expected, value, depth, pos)
	return {
		type = argType,
		expected = expected,
		value = value,
		depth = depth,
		pos = assert(pos),
	}
end

--[[= struct Instruction
	- Function funcName
	- {Argument} args
	- integer num The index of this instruction.
	- integer pos The starting position of the function token in the source.
]]
local function Instruction(funcName, args, num, pos)
	return {
		funcName = funcName,
		args = args,
		num = assert(num),
		pos = assert(pos),
	}
end

--[[= struct CompiledProgram
	A CompiledProgram is a table and is the Bliks equivalent of bytecode; it is
	a representation of a program, ready for interpretation by a >Machine.

	CompiledProgram instances are immutable; the same instance may be passed to
	several concurrently-running machines safely. Furthermore, CompiledProgram
	instances are guaranteed to be composed of only strings, numbers and tables,
	and all table keys are guaranteed to be strings or numbers. Therefore, it is
	possible to serialize them into a format like JSON. However, doing so should
	only be done with caution, since a CompiledProgram's serialization may be
	massive compared to the source string since macros are fully expanded in the
	instance.

	- {Instruction} instructions
	- integer begin

	@compound string any
]]

return {
	Error = Error,
	Token = Token,
	Parameter = Parameter,
	Argument = Argument,
	Instruction = Instruction,
}
