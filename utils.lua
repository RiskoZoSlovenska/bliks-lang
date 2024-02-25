local LEADING_CONTEXT = 15
local TRAILING_CONTEXT = 15
local TRUNCATE_STR = "..."
local TRUNCATE_STR_WIDTH = 3

-- Pretty-print via the inspect library. Only for debugging.
local function pp(a, b)
	local inspect = require("inspect")
	print(inspect(a), b and inspect(b) or "")
end

-- Takes a string, and truncates it around a given index.
local function truncate(str, start)
	str = tostring(str)
	start = start or 1

	local left = math.max(start - LEADING_CONTEXT, 1)
	local right = start + TRAILING_CONTEXT
	local cleaned = str:sub(left, right)
	local pos = math.min(start, LEADING_CONTEXT + 1)

	if left > 1 then
		cleaned = TRUNCATE_STR .. cleaned
		pos = pos + TRUNCATE_STR_WIDTH
	end
	if right < #str then
		cleaned = cleaned .. TRUNCATE_STR
	end

	return cleaned, pos
end

-- Given an Error object, a source string and a source name, returns a
-- neatly-formatted error message.
local function formatError(err, source, sourcename)
	local lineNum = 1
	local line, colNum
	for left, body, right in string.gmatch(source, "()([^\n]*)()") do
		if left <= err.pos and err.pos <= right then
			local leadingWhite, cleaned = body:match("^%s*()(.-)%s*$")
			line = cleaned
			colNum = err.pos - left + 1 - leadingWhite + 1
			break
		end

		lineNum = lineNum + 1
	end

	local truncated, arrowPos = truncate(assert(line), colNum)
	local arrow = truncated:sub(1, arrowPos - 1):gsub("%S", " ") .. "^" -- Preserves tabs

	return string.format(
		"bliks: error: %s:%d: %s\n\t%s\n\t%s",
		sourcename, lineNum, err.message,
		truncated,
		arrow
	)
end


return {
	truncate = truncate,
	formatError = formatError,

	pp = pp,
}
