--[[= [internal] namespace types
	A set of utility functions for handling the Bliks type hierarchy.
]]

local enums = require("enums")
local TokenType = enums.TokenType
local ValueType = enums.ValueType

local structs = require("structs")
local Parameter = structs.Parameter

local ALIASES = { -- Remember to update the docs if you change this
	p = ValueType.pointer,
	n = ValueType.number,
	s = ValueType.string,

	N = ValueType.name,
}

local HIERARCHY = {
	[ValueType.string] = {
		[ValueType.string] = true,
	},
	[ValueType.number] = {
		[ValueType.string] = true,
		[ValueType.number] = true,
	},
	[ValueType.pointer] = {
		[ValueType.string] = true,
		[ValueType.number] = true,
		[ValueType.pointer] = true,
	},

	[ValueType.name] = {
		[ValueType.name] = true,
	},
}

--[[
	Returns whether a subtype (ValueType) is also a supertype (ValueType).
]]
local function is(subtype, supertype)
	return HIERARCHY[subtype][supertype] ~= nil
end

--[[
	Takes a string/number value and returns the most specific ValueType it
	satisfies.
]]
local function typeof(value)
	local asNum = tonumber(value)
	if not asNum then
		return ValueType.string
	end

	if asNum <= 0 or asNum ~= math.floor(asNum) then
		return ValueType.number
	end

	return ValueType.pointer
end

--[[
	Given a name or a literal token, returns the most specific ValueType the
	token's value satisfies. Differs from typeof in that it can return
	ValueType.name for name tokens.
]]
local function typeoftoken(token)
	if token.type == TokenType.name then
		return ValueType.name
	elseif token.type ~= TokenType.literal then
		error("invalid token type passed: " .. token.type, 2)
	end

	return typeof(token.value)
end

--[[
	Parses a string into a ParameterList; mainly used by the >Function utility
	class. The string format is as follows:

	Parameters are whitespace-separated. Each parameter consists of a single
	alphabetical letter, is optionally prefixed by an exclamation mark (!), and
	is optionally suffixed by either a question mark (?) or an asterisk (*).

	Letters map to types like so:
	* p -> ValueType.pointer
	* n -> ValueType.number
	* s -> ValueType.string
	* N -> ValueType.name

	An exclamation mark means the parameter is fixed.
	A question mark means the parameter is optional. An optional parameter must
	be followed either by another optional parameter or a vararg parameter.
	An asterisk means the parameter is a vararg parameter. A vararg parameter
	must be the last parameter in the list.
]]
local function parseParams(paramsStr)
	local params = {
		min = nil,
		max = nil,
	}

	local numOptional = 0
	local hasVararg = false
	for paramStr in string.gmatch(paramsStr, "%S+") do
		if hasVararg then
			error("vararg parameter must be the last one", 2)
		end

		local fixed, typeStr, mod = paramStr:match("^(!?)(%a)([%?%*]?)$")
		if not typeStr then
			error("malformed parameter '" .. paramStr .. "'", 2)
		end

		local typ = ALIASES[typeStr]
		if not typ then
			error("unknown type '" .. typeStr .. "'", 2)
		end

		if mod == "*" then
			hasVararg = true
		elseif mod == "?" then
			numOptional = numOptional + 1
		elseif numOptional > 0 then
			error("optional parameters must be the at end", 2)
		end

		table.insert(params, Parameter(typ, (fixed == "!")))
	end

	params.min = #params - numOptional - (hasVararg and 1 or 0)
	params.max = (hasVararg and math.huge or #params)

	return params
end


return {
	is = is,
	typeof = typeof,
	typeoftoken = typeoftoken,

	parseParams = parseParams,
}
