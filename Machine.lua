local structs = require("structs")
local expandArgs = require("expand")

local Error = structs.Error

-- CONTINUE: Doc and test this. Also maybe some method for manipulating its state externally.
local Machine = {}
Machine.__index = Machine

function Machine.new(compiled, numRegisters)
	local self = setmetatable({}, Machine)

	self._compiled = compiled
	self._registers = {}
	self._numRegisters = numRegisters

	self._buffer = {}

	self._interface = {
		registers = {},
		popBuffer = function()
			return table.remove(self._buffer, 1)
		end,
		nextInstruction = assert(compiled.begin),
		output = nil,
	}

	return self
end

function Machine:push(value)
	table.insert(self._buffer, value)
end

function Machine:step()
	-- Get instruction, or stop if no such
	local curIndex = self._interface.nextInstruction
	local instruction = self._compiled.instructions[curIndex]
	if not instruction then
		return false, nil, nil
	end

	self._interface.nextInstruction = self._interface.nextInstruction + 1

	-- Expand argument, or error
	local args, expandErr = expandArgs(instruction.args, self._registers)
	if not args then
		return false, nil, expandErr
	end

	-- Run function
	local runErr = instruction.func.runFunc(self._interface, self._compiled, curIndex, table.unpack(args))
	if runErr then
		return false, nil, Error(runErr, instruction.pos)
	end

	-- Parse and reset interface table
	for register, value in pairs(self._interface.registers) do
		if register > self._numRegisters then
			return false, nil, Error("register %d is out-of-bounds", instruction.pos, register)
		end

		self._registers[register] = value
		self._interface.registers[register] = nil
	end

	local data = self._interface.output
	self._interface.output = nil

	return true, data, nil
end

function Machine:stepUntilOutput()
	local running, data, err
	repeat
		running, data, err = self:step()
	until data or not running

	return running, data, err
end


return Machine
