local LEADING_CONTEXT = 10
local TRAILING_CONTEXT = 10
local TRUNCATE_STR = "..."
local TRUNCATE_STR_WIDTH = 3

local function pp(a, b) -- Only for debugging
	local inspect = require("inspect")
	print(inspect(a), b and inspect(b) or "")
end

local function truncate(str, start)
	str = tostring(str)
	start = start or 1

	local pos = 1
	if start > LEADING_CONTEXT then
		str = TRUNCATE_STR .. str:sub(start - LEADING_CONTEXT)
		pos = LEADING_CONTEXT + TRUNCATE_STR_WIDTH
	end
	if #str > TRAILING_CONTEXT then
		str = str:sub(1, TRAILING_CONTEXT) .. TRUNCATE_STR
	end

	return str, pos
end

local function formatError(err, source, filename)
	local lineNum = select(2, source:sub(1, err.pos - 1):gsub("\n", "\n")) + 1
	local colNum = source:sub(1, err.pos - 1):find("\n.-$")

	local truncated, arrowPos = truncate(source, err.pos)
	local arrow = (string.rep(" ", arrowPos) .. "^..."):sub(1, #truncated)

	return string.format(
		"error in %s on line %d, col %d: %s\n\t%s\n\t%s",
		filename, lineNum, colNum, err.msg,
		truncated,
		arrow
	)
end


return {
	truncate = truncate,
	formatError = formatError,

	pp = pp,
}
