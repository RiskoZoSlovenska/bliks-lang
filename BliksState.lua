local errors = require("errors")
local resolver = require("resolver")
local enums = require("enums")
local parse = require("parse")

local FunctionResult = enums.FunctionResult



local function formatLineAndFunc(lineNum, funcName, msg, ...)
	return errors.formatLine(lineNum, errors.formatFuncName(funcName, msg, ...))
end



local State = {}
State.__index = State



function State.fromParseState(parseState, options)
	local self = setmetatable({}, State)

	self._instructions = parseState.instructions

	self._labels = parseState.labels
	self._openLabels = parseState.openLabels

	self._registers = {n = options.numOfRegisters}
	self._buffer = {}

	self._nextInstruction = parseState.firstInstruction
	self._isFinished = false
	self._err = nil

	self._interface = {
		cur = self._nextInstruction,

		labels = self._labels,
		openLabels = self._openLabels,

		registers = self._registers,
		buffer = self._buffer,
	}

	p(self._instructions)

	self._startTime = os.clock()

	return self
end

function State.fromString(str, options)
	local parseState, err = parse(str, options)
	if parseState then
		return State.fromParseState(parseState, options), nil
	else
		return nil, err
	end
end



function State:push(value)
	table.insert(self._buffer, value)
end

function State:step()
	if self._isFinished then
		return false, self._err
	end

	-- Retrieve current instruction
	local curInstruction = self._nextInstruction
	local instruction = self._instructions[curInstruction]
	if not instruction then return self:_stop(nil) end

	-- Expand arguments
	local func, args, funcName, lineNum = table.unpack(instruction)
	local expanded, expansionErr = resolver.expandArgs(args, self._registers)
	if not expanded then
		return self:_stop(formatLineAndFunc(lineNum, funcName, expansionErr))
	end

	-- Update interface table
	self._interface.cur = curInstruction

	-- Call function
	-- print(funcName)
	local action, res = func(self._interface, table.unpack(expanded, 1, expanded.n))
	local output = nil

	if not action then -- Failed; stop and throw error
		return self:_stop(formatLineAndFunc(lineNum, funcName, res))

	elseif action == FunctionResult.GOTO then -- goto command; go to instruction, or end
		local index = tonumber(res)

		if not index then
			error("invalid goto index returned by function")

		elseif index < 1 or index > #self._instructions then
			return self:_stop(nil)

		else
			self._nextInstruction = index
		end

	else -- No-jump success
		self._nextInstruction = curInstruction + 1

		if action == true then -- No-action success; continue to next instruction
			-- Do nothing
		elseif action == FunctionResult.WRITE then -- Write result
			output = res
		else
			self._registers[action] = res
		end
	end

	return true, output
end

function State:_stop(err)
	self._isFinished = os.clock()
	self._err = err

	return false, err
end



return State