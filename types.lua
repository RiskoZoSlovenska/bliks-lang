--[[= namespace types
	A set of utility functions for handling the Blicks type hierarchy and
	resolving parameters.
]]

local enums = require("enums")
local TokenType = enums.TokenType
local ValueType = enums.ValueType

local ALIASES = {
	p = ValueType.pointer,
	n = ValueType.number,
	s = ValueType.string,

	i = ValueType.name,
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

local function is(subtype, supertype)
	return HIERARCHY[subtype][supertype] ~= nil
end

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

local function typeoftoken(token)
	if token.type == TokenType.name then
		return ValueType.name
	end

	return typeof(token.value)
end

local function parseParams(paramsStr)
	local params = {}

	local numOptional = 0
	local hasVararg = false
	for paramStr in string.gmatch(paramsStr, "%S+") do
		if hasVararg then
			error("vararg parameter must be the last one", 2)
		end

		local typeStr, mod = paramStr:match("^(%a)([%?%*]?)$")
		if not typeStr then
			error("malformed parameter '" .. paramStr .. "'", 2)
		end

		local typ = ALIASES[typeStr]
		if not typ then
			error("unknown type '" .. typeStr .. "'", 2)
		end

		if mod == "?" then
			numOptional = numOptional + 1
		elseif numOptional > 0 then
			error("optional parameters must be the at end", 2)
		elseif mod == "*" then
			hasVararg = true
		end

		table.insert(params, typ)
	end

	params.min = #params - numOptional - (hasVararg and 1 or 0)
	params.max = (hasVararg and math.huge or #params)

	return params
end


return {
	parseParams = parseParams,

	is = is,
	typeof = typeof,
	typeoftoken = typeoftoken,
}
