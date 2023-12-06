local types = require("types") -- icky!

--[[= struct Error
	- string message
	- integer pos
]]
local function Error(message, pos, ...)
	return {
		message = string.format(message, ...),
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

--[[= struct Argument
	- ArgumentType type
	- ValueType expectedType
	- any value
	- integer? depth
	- integer pos Starting position of the param token in the source.
]]
local function Argument(type, expected, value, depth, pos)
	return {
		type = type,
		expected = expected,
		value = value,
		depth = depth,
		pos = assert(pos),
	}
end

--[[= struct Instruction
	- Function func
	- {Parameter} args
	- {string:any} data Arbitrary data stored for this instruction.
	- integer num The index of this instruction.
	- integer pos Starting position of the function token in the source.
]]
local function Instruction(func, args, num, pos)
	return {
		func = func,
		args = args,
		num = assert(num),
		pos = assert(pos),
	}
end


return {
	Error = Error,
	Token = Token,
	Argument = Argument,
	Instruction = Instruction,
}
