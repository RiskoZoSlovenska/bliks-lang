local parse = require("parse")
local solve = require("solve")
local Machine = require("Machine")
local utils = require("utils")
local stdlib = require("stdlib")


local function compile(source, lib)
	local parsed, parseErr = parse(source)
	if not parsed then
		return nil, parseErr
	end

	local compiled, compileErr = solve(parsed, lib or stdlib)
	if not compiled then
		return nil, compileErr
	end

	return compiled, nil
end

local function machineFromCompiled(compiled, lib, numRegisters)
	return Machine.fromCompiled(compiled, lib or stdlib, numRegisters or math.huge)
end

local function machineFromSource(source, lib, numRegisters)
	local compiled, err = compile(source, lib)
	if not compiled then
		return nil, err
	end

	return machineFromCompiled(compiled, lib, numRegisters), nil
end


return {
	stdlib = stdlib,

	compile = compile,
	machineFromCompiled = machineFromCompiled,
	machineFromSource = machineFromSource,

	formatError = utils.formatError,
}
