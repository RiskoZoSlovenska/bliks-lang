local types = require("types")



local function new(params, isStatic, func)
	return {
		params = types.parseParams(params),
		isStatic = isStatic,
		func = assert(func),
	}
end

local function basic(params, func)
	return new(params, false, function(out, state, num, pointer, ...)
		local ret, err = func(...)
		if err then
			return err
		end

		out.registers[pointer] = ret
	end)
end

local function basicBool(params, func)
	return basic(params, function(...) return func(...) and "true" or "" end)
end

local function basicProtected(params, func)
	return new(params, false, function(out, state, num, pointer, ...)
		local ok, ret = pcall(func, ...)
		if not ok then
			return ret
		end

		out.registers[pointer] = ret
	end)
end


return {
	new = new,
	basic = basic,
	basicProtected = basicProtected,
	basicBool = basicBool,
}
