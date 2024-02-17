local parse = require("parse")
local solve = require("solve")
local Machine = require("Machine")
local utils = require("utils")
local defaultStdlib = require("stdlib")


local function createMachine(source, stdlib, numRegisters)
	local parsed, parseErr = parse(source)
	if not parsed then
		return nil, parseErr
	end

	local compiled, compileErr = solve(parsed, stdlib or defaultStdlib)
	if not compiled then
		return nil, compileErr
	end

	return Machine.new(compiled, numRegisters or math.huge), nil
end


return {
	createMachine = createMachine,
	formatError = utils.formatError,
}
