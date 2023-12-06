local Function = require("Function")

local f = string.format


local function putLabel(state, num, label, suffix)
	state.std_labels = state.std_labels or {}
	state.std_labels[label] = state.std_labels[label] or {}
	table.insert(state.std_labels[label], num)
end

local function putConstantLabel(label)
	return function(out, state, cur, suffix)
		return putLabel(state, cur, label .. (suffix or ""))
	end
end

local function getLabelPositions(acc, label)
	return acc.std_labels and acc.std_labels[label] or nil
end

local function jumpToNextLabel(out, state, cur, label)
	local labels = getLabelPositions(state, label)
	if labels then
		for _, labelPos in ipairs(labels) do
			if labelPos > cur then
				out.nextInstruction = labelPos
				return
			end
		end
	end

	return f("no succeeding label '%s'", label)
end

local function jumpToPreviousLabel(out, state, cur, label)
	local labels = getLabelPositions(state, label)
	if labels then
		local i = 1
		while i <= #labels and labels[i] < cur do
			i = i + 1
		end

		if i > 1 then
			out.nextInstruction = labels[i - 1]
		else
			return f("no preceeding label '%s'", label)
		end
	end
end

local function goTo(out, state, cur, label)
	local labels = getLabelPositions(state, label)
	if not labels then
		return f("no such label '%s'", label)
	elseif #labels > 1 then
		return f("label '%s' appears more than once; jump is ambiguous", label)
	else
		out.nextInstruction = assert(labels[1])
	end
end

local function areEqual(a, b)
	if a == b then
		return true
	end

	local num = tonumber(a)
	return (num ~= nil) and num == tonumber(b)
end


return {
	-- Values
	["let"] = Function.new("i s", true, function(state, num, name, value)
		state.macros[name] = value
	end),
	["set"] = Function.basic("p s", function(value) return value end),

	-- Starting and stopping
	["begin"] = Function.new("", true, function(state, num)
		if state.begin then
			return "beginning has already been defined"
		end

		state.begin = num
	end),
	["end"] = Function.new("", false, function(out, state, num)
		out.nextInstruction = -1
	end),
	["throw"] = Function.new("s", false, function(out, state, num, message)
		return message
	end),
	["==="] = Function.new("", false, function(out, state, num)
		return "leakage detected"
	end),

	-- Labels
	[">"] = Function.new("i", true, putLabel),
	["else"] = Function.new("s?", true, putConstantLabel("_else")),
	["repeat"] = Function.new("s?", true, putConstantLabel("_repeat")),

	-- Jumping
	["goto"] = Function.new("i", false, goTo),
	["jump"] = Function.new("i", false, jumpToNextLabel),
	["if"] = Function.new("s s?", false, function(out, state, cur, value, suffix)
		if value == "" then
			return jumpToNextLabel(out, state, cur, "_else" .. (suffix or ""))
		end
	end),
	["while"] = Function.new("s s?", false, function(out, state, cur, value, target, suffix)
		if not areEqual(value, target or "") then
			return jumpToPreviousLabel(out, state, cur, "_repeat" .. (suffix or ""))
		end
	end),
	["call"] = Function.new("i", false, function(out, state, cur, label)
		if state.std_return then
			return "already in a function!"
		end

		state.std_return = cur
		return goTo(out, state, cur, label)
	end),
	["return"] = Function.new("", false, function(out, state, cur)
		if not state.std_return then
			return "not in a function!"
		end

		out.nextInstruction = state.std_return
		state.std_return = nil
	end),

	-- TODO:
	-- read
	-- readnum
	-- write
	-- writef

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
		if b == 0 then return nil, "cannot divide by zero" end
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
	["upper"]  = Function.basic("p s",     string.upper),
	["lower"]  = Function.basic("p s",     string.lower),
	["revstr"] = Function.basic("p s",     string.reverse),
	["substr"] = Function.basic("p s n n", string.sub),
	["len"]    = Function.basic("p s",     string.len),
	["byte"]   = Function.basic("p s",     string.byte),
	["char"]   = Function.basicProtected("p s",    string.char),
	["match"]  = Function.basicProtected("p s s",  string.match),
	["gsub"]   = Function.basicProtected("p s s",  string.gsub),
	["format"] = Function.basicProtected("p s s*", string.format),

	-- Logic
	["not"] = Function.basicBool("p s", function(a) return a ~= "" end),
	["and"] = Function.basic("p s s*", function(...)
		for i = 1, select("#", ...) do
			if select(i, ...) == "" then
				return false
			end
		end
		return true
	end),
	["or"]  = Function.basic("p s s*", function(...)
		for i = 1, select("#", ...) do
			if select(i, ...) ~= "" then
				return true
			end
		end
		return false
	end),

	-- Equality comparisons
	["equal"] = Function.basic("p s s s*", function(...)
		for i = 1, select("#", ...) do
			if areEqual((...), select(i, ...)) then
				return true
			end
		end

		return false
	end),
	["notequal"] = Function.basic("p s s", function(a, b) return not areEqual(a, b) end),

	-- Number comparisons
	["less"]      = Function.basicBool("p n n", function(a, b) return a <  b end),
	["lessequal"] = Function.basicBool("p n n", function(a, b) return a <= b end),
	["more"]      = Function.basicBool("p n n", function(a, b) return a >  b end),
	["moreequal"] = Function.basicBool("p n n", function(a, b) return a >= b end),

	-- String comparisons
	["sless"]      = Function.basicBool("p s s", function(a, b) return tostring(a) <  tostring(b) end),
	["slessequal"] = Function.basicBool("p s s", function(a, b) return tostring(a) <= tostring(b) end),
	["smore"]      = Function.basicBool("p s s", function(a, b) return tostring(a) >  tostring(b) end),
	["smoreequal"] = Function.basicBool("p s s", function(a, b) return tostring(a) >= tostring(b) end),
}
