local Function = require("Function")

local f = string.format


local function putLabel(state, label, offset)
	state.std_labels = state.std_labels or {}
	state.std_labels[label] = state.std_labels[label] or {}
	table.insert(state.std_labels[label], state.curInstruction + (offset or 0))
	return nil
end

local function getLabelPositions(acc, label)
	return acc.std_labels and acc.std_labels[label] or nil
end

local function jumpToNextLabel(out, state, label)
	local labels = getLabelPositions(state, label)
	if labels then
		for _, labelPos in ipairs(labels) do
			if labelPos > out.curInstruction then
				out.nextInstruction = labelPos
				return
			end
		end
	end

	return f("no succeeding label '%s'", label)
end

local function jumpToPreviousLabel(out, state, label)
	local labels = getLabelPositions(state, label)
	if labels then
		local i = 1
		while i <= #labels and labels[i] < out.curInstruction do
			i = i + 1
		end

		if i > 1 then
			out.nextInstruction = labels[i - 1]
		else
			return f("no preceding label '%s'", label)
		end
	end
end

local function goTo(out, state, label)
	local labels = getLabelPositions(state, label)
	if not labels then
		return f("no such label '%s'", label)
	elseif #labels > 1 then
		return f("label '%s' appears more than once; jump is ambiguous", label)
	else
		out.nextInstruction = assert(labels[1])
	end
end


local function putJumpDest(state, dest)
	state.std_jumpDests = state.std_jumpDests or {}
	state.std_jumpDests[state.curInstruction] = dest
	return nil
end

local function getJumpDest(state, out)
	return state.std_jumpDests[out.curInstruction]
end

local function increaseCounter(state, name)
	local current = (state[name] or 0) + 1
	state[name] = current
	return current
end

local function decreaseCounter(state, name)
	local current = state[name]
	if not current then return nil end

	state[name] = current - 1
	return current
end

local function c_incrCounterAndPutAsJumpDest(labelBase, counterName)
	return function(state)
		return putJumpDest(state, labelBase .. increaseCounter(state, counterName))
	end
end


local function areEqual(a, b)
	if a == b then
		return true
	end

	local num = tonumber(a)
	return (num ~= nil) and num == tonumber(b)
end

local function format(fmt, ...)
	local args = {...}
	local i = 0
	return (fmt:gsub("%%", function(arg)
		i = i + 1
		return args[i] or "INVALID_ESCAPE"
	end))
end


-- CONTINUE: Function docstrings, manually catch errors instead of pcall, docs, tests
return {
	-- Values
	["let"] = Function.compile("!N !s", function(state, name, value)
		state.macros[name] = value
	end),
	["set"] = Function.basic("p s", function(value) return value end),

	-- Starting and stopping
	["begin"] = Function.compile("", function(state)
		if state.begin then
			return "beginning has already been defined"
		end

		state.begin = state.curInstruction
	end),
	["stop"] = Function.new("", nil, function(out, state)
		out.nextInstruction = -1
	end),
	["throw"] = Function.new("s", nil, function(out, state, message)
		return message
	end),
	["assert"] = Function.new("s s?", nil, function(out, state, value, message)
		if value ~= "" then return end
		return message or "value was false"
	end),
	["==="] = Function.new("", nil, function(out, state)
		return "boundary was crossed"
	end),

	-- Jumping
	[">"] = Function.compile("!N", putLabel),
	["goto"] = Function.new("N", nil, goTo),
	["jump"] = Function.new("N", nil, jumpToNextLabel),

	-- If statements
	["if"] = Function.new("s", c_incrCounterAndPutAsJumpDest("_ELSE", "std_ifLevel"), function(out, state, value)
		if value ~= "" then return nil end
		return jumpToNextLabel(out, state, getJumpDest(state, out))
	end),
	["ifnot"] = Function.new("s", c_incrCounterAndPutAsJumpDest("_ELSE", "std_ifLevel"), function(out, state, value)
		if value == "" then return nil end
		return jumpToNextLabel(out, state, getJumpDest(state, out))
	end),
	["else"] = Function.compile("", function(state)
		local level = decreaseCounter(state, "std_ifLevel")
		if not level or level < 1 then
			return "else defined without a corresponding if/ifnot"
		end
		return putLabel(state, "_ELSE" .. level, 0)
	end),

	-- Loops
	["repeat"] = Function.compile("", function(state)
		return putLabel(state, "_LOOP" .. increaseCounter(state, "std_loopLevel"), 0)
	end),
	["endif"] = Function.new("s",
		function(state)
			local level = state.std_loopLevel
			if not level or level < 1 then
				return "endif not within a loop"
			end

			return putJumpDest(state, "_END" .. level)
		end,
		function(out, state, value)
			if value == "" then return nil end
			return jumpToNextLabel(out, state, getJumpDest(state, out))
		end
	),
	["while"] = Function.new("s",
		function(state)
			local level = increaseCounter(state, "std_loopLevel")
			putLabel(state, "_LOOP" .. level, 0)
			return putJumpDest(state, "_END" .. level)
		end,
		function(out, state, value)
			if value ~= "" then return nil end
			return jumpToNextLabel(out, state, getJumpDest(state, out))
		end
	),
	["for"] = Function.new("p n n n?",
		function(state)
			local level = increaseCounter(state, "std_loopLevel")
			putLabel(state, "_LOOP" .. level, 0)
			return putJumpDest(state, "_END" .. level)
		end,
		function(out, state, pointer, i, stop, step)
			if step == 0 then
				return "step cannot be nil"
			end
			step = step or 1

			i = i + step
			out.registers[pointer] = i

			if (step > 0 and i > stop) or (step < 0 and i < stop) then
				return jumpToNextLabel(out, state, getJumpDest(state, out))
			end
		end
	),
	["break"] = Function.new("", c_incrCounterAndPutAsJumpDest("_END", "std_loopLevel"), function(out, state)
		return jumpToNextLabel(out, state, getJumpDest(state, out))
	end),
	["continue"] = Function.new("", c_incrCounterAndPutAsJumpDest("_LOOP", "std_loopLevel"), function(out, state)
		return jumpToPreviousLabel(out, state, getJumpDest(state, out))
	end),
	["end"] = Function.new("",
		function(state)
			local level = decreaseCounter(state, "std_loopLevel")
			if not level or level < 1 then
				return "end not closing any loop"
			end

			putJumpDest(state, "_LOOP" .. level)
			return putLabel(state, "_END" .. level, 1)
		end, function(out, state)
			return jumpToPreviousLabel(out, state, getJumpDest(state, out))
		end
	),

	["func"] = Function.compile("!N", function(state, name)
		if getLabelPositions(state, name) then
			return "cannot define function because this label already exists"
		end

		return putLabel(state, name, 0)
	end),
	["call"] = Function.new("N", nil, function(out, state, label)
		if state.std_return then
			return "already in a function!"
		end

		state.std_return = out.curInstruction
		return goTo(out, state, label)
	end),
	["return"] = Function.new("", nil, function(out, state)
		if not state.std_return then
			return "not in a function!"
		end

		out.nextInstruction = state.std_return + 1
		state.std_return = nil
	end),

	["read"] = Function.new("p", nil, function(out, state, pointer)
		out.registers[pointer] = out.popBuffer()
	end),
	["readnum"] = Function.new("p", nil, function(out, state, pointer)
		out.registers[pointer] = tonumber(out.popBuffer())
	end),
	["poll"] = Function.new("p", nil, function(out, state, pointer)
		local data = out.popBuffer()
		if not data then
			out.output = -1
			out.nextInstruction = out.curInstruction
		else
			out.registers[pointer] = data
		end
	end),
	["pollnum"] = Function.new("p", nil, function(out, state, pointer)
		local data = tonumber(out.popBuffer())
		if not data then
			out.output = -1
			out.nextInstruction = out.curInstruction
		else
			out.registers[pointer] = data
		end
	end),
	["write"] = Function.new("s", nil, function(out, state, data)
		out.output = tostring(data)
	end),
	["writef"] = Function.new("s s*", nil, function(out, state, data, ...)
		out.output = format(tostring(data), ...)
	end),

	-- Math functions
	["add"] = Function.basic("p n n n*", function(first, ...)
		local sum = first
		for i = 1, select("#", ...) do
			sum = sum + select(i, ...)
		end
		return sum
	end),
	["mul"] = Function.basic("p n n n*", function(first, ...)
		local product = first
		for i = 1, select("#", ...) do
			product = product * select(i, ...)
		end
		return product
	end),
	["sub"] = Function.basic("p n n", function(a, b) return a - b end),
	["exp"] = Function.basic("p n n", function(a, b) return a ^ b end),
	["div"] = Function.basic("p n n", function(a, b)
		if b == 0 then return nil, "attempt to divide by zero" end
		return a / b
	end),
	["neg"] = Function.basic("p n", function(a) return -a end),
	["tonum"] = Function.basic("p s", function(a) return tonumber(a) or "" end),
	["log"]   = Function.basic("p n n",  math.log),
	["flr"]   = Function.basic("p n",    math.floor),
	["cie"]   = Function.basic("p n",    math.ceil),
	["sin"]   = Function.basic("p n",    math.sin),
	["cos"]   = Function.basic("p n",    math.cos),
	["tan"]   = Function.basic("p n",    math.tan),
	["asin"]  = Function.basic("p n",    math.asin),
	["acos"]  = Function.basic("p n",    math.acos),
	["atan"]  = Function.basic("p n",    math.atan),
	["atan2"] = Function.basic("p n n",  math.atan2),
	["deg"]   = Function.basic("p n",    math.deg),
	["rad"]   = Function.basic("p n",    math.rad),
	["max"]   = Function.basic("p n n*", math.max),
	["min"]   = Function.basic("p n n*", math.min),
	["rand"]  = Function.basic("p",      math.random),
	["randn"] = Function.basic("p n n",  math.random),

	-- String functions
	["concat"] = Function.basic("p s s*", function(...) return table.concat({...}) end),
	["upper"]  = Function.basic("p s",    string.upper),
	["lower"]  = Function.basic("p s",    string.lower),
	["revstr"] = Function.basic("p s",    string.reverse),
	["len"]    = Function.basic("p s",    string.len),
	["byte"]   = Function.basic("p s",    string.byte),

	-- TODO: These are unsafe, handle errors in them better or smth
	["substr"] = Function.basic("p s n n", string.sub),
	["char"]   = Function.basic("p s",     string.char),
	["match"]  = Function.basic("p s s",   string.match),
	["gsub"]   = Function.basic("p s s",   string.gsub),
	["format"] = Function.basic("p s s*",  string.format),

	-- Logic
	["not"] = Function.basicBool("p s", function(a) return a ~= "" end),
	["and"] = Function.basicBool("p s s*", function(...)
		for i = 1, select("#", ...) do
			if select(i, ...) == "" then
				return false
			end
		end
		return true
	end),
	["or"]  = Function.basicBool("p s s*", function(...)
		for i = 1, select("#", ...) do
			if select(i, ...) ~= "" then
				return true
			end
		end
		return false
	end),

	-- Equality comparisons
	["equal"] = Function.basicBool("p s s s*", function(...)
		for i = 1, select("#", ...) do
			if areEqual((...), select(i, ...)) then
				return true
			end
		end

		return false
	end),
	["notequal"] = Function.basicBool("p s s", function(a, b) return not areEqual(a, b) end),

	-- Number comparisons
	["less"]      = Function.basic("p n n", function(a, b) return (a <  b) and a or "" end),
	["lessequal"] = Function.basic("p n n", function(a, b) return (a <= b) and a or "" end),
	["more"]      = Function.basic("p n n", function(a, b) return (a >  b) and a or "" end),
	["moreequal"] = Function.basic("p n n", function(a, b) return (a >= b) and a or "" end),

	-- String comparisons
	["sless"]      = Function.basicBool("p s s", function(a, b) return tostring(a) <  tostring(b)end),
	["slessequal"] = Function.basicBool("p s s", function(a, b) return tostring(a) <= tostring(b)end),
	["smore"]      = Function.basicBool("p s s", function(a, b) return tostring(a) >  tostring(b)end),
	["smoreequal"] = Function.basicBool("p s s", function(a, b) return tostring(a) >= tostring(b)end),
}
