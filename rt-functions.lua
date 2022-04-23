local enums = require("enums")
local utils = require("func-utils")

local FunctionResult = enums.FunctionResult
local GOTO, WRITE = FunctionResult.GOTO, FunctionResult.WRITE

local truthy, bool = utils.truthy, utils.bool
local basic, protected, constant = utils.basic, utils.protected, utils.constant
local boolChain, makeRead = utils.boolChain, utils.makeRead

local f = string.format



local function gotoEnd()
	return GOTO, -1
end

local function goto_(state, label)
	local positions = state.labels[label]
	if positions then
		return GOTO, positions[1]

	elseif state.openLabels[label] then
		return gotoEnd()

	else
		return false, f("no label %q", label)
	end
end

local function jump(state, label)
	local positions = state.labels[label]
	if positions then
		for _, pos in ipairs(positions) do
			if pos > state.cur then
				return GOTO, pos
			end
		end
	elseif state.openLabels[label] then
		return gotoEnd()
	end

	return false, f("no following label %q", label) -- First branch may not exit - cannot put this into else
end

local function call(state, label)
	state.lastCall = state.cur

	return goto_(state, label)
end

local function return_(state)
	if not state.lastCall then
		return false, "must invoke the call function before returning"
	end

	return GOTO, state.lastCall + 1
end

local function if_(state, cond)
	return jump(state, truthy(cond) and "then" or "else")
end

local function repeat_(state, out, cur, target, step, label)
	if step == 0 then
		return false, "step may not be zero"
	end

	local reached = false
	if step > 0 then
		reached = cur >= target
	else
		reached = cur <= target
	end

	state.registers[out] = cur + step

	if reached then
		return true, nil
	else
		local positions = state.labels[label]
		local last = nil
		if positions then
			for _, pos in ipairs(positions) do
				if pos > state.cur then break end

				last = pos
			end
		end
		if last then
			return GOTO, last
		end

		return false, f("no leading label %q", label)
	end
end



local function extract(state, out, tbl, index)
	if index % 1 ~= 0 then
		return false, "invalid index: " .. index
	end

	local i = 1
	for value in string.gmatch(tbl, "[^;]*") do
		if i == index then
			return out, value
		end
	end

	return false, "index out of range: " .. index
end

local function extractnum(state, out, tbl, index)
	local ret, value = extract(state, out, tbl, index)
	if not ret then return ret, value end

	return ret, tonumber(value)
end




local protectedFormat = protected(string.format)

--[[--
	[funcName] = {
		params,
		return,
		function
	}

	params is a string of space-separated ParamType characters.
	The last param may be followed by a `+` to indicate varargs.
	return is one of the same as params. May also have varreturns.
]]
return {
	-- General
	set = {"p a", "a", function(state, out, value) return out, value end},

	-- Flow
	["goto"]   = {"i", "", goto_},
	jump       = {"i", "", jump},
	call       = {"i", "", call},
	["return"] = {"",  "", return_},
	["if"]     = {"a", "", if_},
	["repeat"] = {"p n n n i", "n", repeat_},
	stop       = {"",  "", function(state) return gotoEnd() end},
	throw      = {"s", "", function(state, err) return false, err end},

	-- I/O
	read    = {"p", "a",   makeRead(nil)},
	readnum = {"p", "a",   makeRead(tonumber)},
	write   = {"a", "",    function(state, inp)      return WRITE, inp end},
	writef  = {"s a+", "", function(state, fmt, ...) return protectedFormat(state, WRITE, fmt, ...) end},

	-- Math
	tonumber = {"p a", "n", function(state, out, value)    return out, tonumber(value) end},
	add    = {"p n n", "n", function(state, out, in1, in2) return out, in1 + in2 end},
	sub    = {"p n n", "n", function(state, out, in1, in2) return out, in1 - in2 end},
	mul    = {"p n n", "n", function(state, out, in1, in2) return out, in1 * in2 end},
	exp    = {"p n n", "n", function(state, out, in1, in2) return out, in1 ^ in2 end},
	div    = {"p n n", "n", function(state, out, in1, in2)
		if in2 == 0 then return false, "cannot divide by zero" end

		return out, in1 / in2
	end},
	log    = {"p n n",  "n", basic(math.log)},
	flr    = {"p n",    "n", basic(math.floor)},
	cie    = {"p n",    "n", basic(math.ceil)},
	sin    = {"p n",    "n", basic(math.sin)},
	cos    = {"p n",    "n", basic(math.cos)},
	tan    = {"p n",    "n", basic(math.tan)},
	asin   = {"p n",    "n", basic(math.asin)},
	acos   = {"p n",    "n", basic(math.acos)},
	atan   = {"p n",    "n", basic(math.atan)},
	atan2  = {"p n n",  "n", basic(math.atan2)},
	deg    = {"p n",    "n", basic(math.deg)},
	rad    = {"p n",    "n", basic(math.rad)},
	max    = {"p n n+", "n", basic(math.max)},
	min    = {"p n n+", "n", basic(math.min)},
	random = {"p",      "n", basic(math.random)},
	huge   = {"p",      "n", constant(math.huge)},
	pi     = {"p",      "n", constant(math.pi)},

	-- String functions
	concat = {"p s+",    "s", function(state, out, ...) return out, table.concat({...}) end},
	upper  = {"p s",     "s", basic(string.upper)},
	lower  = {"p s",     "s", basic(string.lower)},
	revstr = {"p s",     "s", basic(string.reverse)},
	substr = {"p s n n", "s", basic(string.sub)},
	len    = {"p s",     "n", basic(string.len)},
	byte   = {"p s",     "n", basic(string.byte)},
	char   = {"p n",     "s", protected(string.char)},
	match  = {"p s s",   "s", protected(string.match)},
	gsub   = {"p s s",   "s", protected(string.gsub)},
	format = {"p s s+",  "s", protectedFormat},

	-- Logic
	["not"] = {"p a",  "n", function(state, out, value) return out, bool(not truthy(value)) end},
	["and"] = {"p a+", "n", boolChain(true,  function(a, b) return a and b end)},
	["or"]  = {"p a+", "n", boolChain(false, function(a, b) return a or  b end)},

	-- Equality comparisons
	equal    = {"p a+", "n", function(state, out, ...)
		local val = (...)
		for i = 2, select("#", ...) do
			if not val == select(i, ...) then
				return out, bool(false)
			end
		end

		return out, bool(true)
	end},
	notequal = {"p a a", "n", function(state, out, in1, in2) return out, bool(in1 ~= in2) end},

	-- Number comparisons
	less      = {"p n n", "n", function(state, out, in1, in2) return out, bool(in1 <  in2) end},
	lessequal = {"p n n", "n", function(state, out, in1, in2) return out, bool(in1 <= in2) end},
	more      = {"p n n", "n", function(state, out, in1, in2) return out, bool(in1 >  in2) end},
	moreequal = {"p n n", "n", function(state, out, in1, in2) return out, bool(in1 >= in2) end},

	-- String comparisons
	sless      = {"p s s", "n", function(state, out, in1, in2) return out, bool(tostring(in1) <  tostring(in2)) end},
	slessequal = {"p s s", "n", function(state, out, in1, in2) return out, bool(tostring(in1) <= tostring(in2)) end},
	smore      = {"p s s", "n", function(state, out, in1, in2) return out, bool(tostring(in1) >  tostring(in2)) end},
	smoreequal = {"p s s", "n", function(state, out, in1, in2) return out, bool(tostring(in1) >= tostring(in2)) end},

	-- Table
	size       = {"p t", "n",  function(state, out, tbl) return out, select(2, tbl:gsub(";", "")) + 1 end},
	pack       = {"p s+", "t", function(state, out, ...) return out, table.concat({...}, ";")         end},
	pop        = {"p t", "t",  function(state, out, tbl) return out, tbl:match("(.*);?[^;]*$")        end},
	extract    = {"p t n", "s", extract},
	extractnum = {"p t n", "n", extractnum},
	append = {"p a s", "t", function(state, out, tbl, value)
		if tbl == nil then
			return out, tostring(value)
		else
			return out, tbl .. ";" .. value
		end
	end},
}