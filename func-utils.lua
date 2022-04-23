--[[--
	A collection of general utilities for writing functions.
]]



local function truthy(value)
	return value ~= nil and tonumber(value) ~= 0
end

local function bool(value)
	return value and 1 or 0
end



local function basic(func)
	return function(state, out, ...)
		return out, (func(...))
	end
end

local function protected(func)
	return function(state, out, ...)
		local success, res = pcall(func, ...)
		if not success then return false, res end

		return out, res
	end
end

local function constant(value)
	return function(state, out)
		return out, value
	end
end


local function makeRead(extra)
	return function(state, out)
		local value = table.remove(state.buffer, 1)
		return out, extra and extra(value) or value
	end
end

local function boolChain(initial, func)
	return function(state, out, ...)
		local res = initial
		for i = 1, select("#", ...) do
			res = func(res, truthy(select(i, ...)))
		end

		return out, bool(res)
	end
end



return {
	truthy = truthy,
	bool = bool,

	basic = basic,
	protected = protected,
	constant = constant,
	boolChain = boolChain,

	makeRead = makeRead
}