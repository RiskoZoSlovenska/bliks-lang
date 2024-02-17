local types = require("types")



local function new(params, compileFunc, runFunc)
	return {
		params = types.parseParams(params),
		compileFunc = compileFunc,
		runFunc = runFunc,
	}
end

local function compile(params, func)
	return new(params, func, nil)
end

local function basic(params, func)
	return new(params, nil, function(out, state, pointer, ...)
		local ok, ret, err = pcall(func, ...)
		if not ok then
			return ret
		elseif err then
			return err
		end

		out.registers[pointer] = ret
	end)
end

local function basicBool(params, func)
	return basic(params, function(...) return func(...) and "true" or "" end)
end


return {
	new = new,
	compile = compile,
	basic = basic,
	basicBool = basicBool,
}
