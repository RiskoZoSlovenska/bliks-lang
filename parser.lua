--[[
	- Split up source into lines and parse each line separately.
	- Split every line into segments at word boundaries.
	- Iterate the segments in each line.
	  - If whitespace, drop.
	  - If comment, stop iterating.
	  - If string begin:
	    - If the string ends on the same segment, tokenize it.
		- Otherwise, consume segments until a string end is found.
	  - Otherwise, attempt to tokenize the segment
	    - Match number
	    - Match nil
	    - Match retrieval
	    - Match back retrieval
	    - Match identifier
]]

local TokenType = require("./enums").TokenType

local RESERVED_SET = "[\"'%d%.@<#+-]"
local ESCAPES = {
	s = "\\",
	q = "\"",
	n = "\n",
	t = "\t",
}



local function Literal(value)
	return { TokenType.literal, value }
end

local function Identifier(name)
	return { TokenType.identifier, name }
end

local function Retrieval(start, depth)
	return { TokenType.retrieval, start, depth }
end

local function BackRetrieval()
	return { TokenType.back_retrieval }
end



local function charAt(str, at)
	return str:sub(at, at)
end

-- Strip flanking quotes and handle escapes
local function resolveString(str)
	local err, errPos = nil, nil
	local cleaned = str
		:sub(2, #str - 1)
		:gsub("\\(%d%d%d)", utf8.char)
		:gsub("()\\u{(%x+)}", function(pos, code)
			local num = tonumber(code, 16)

			if num > 0x10FFFF then
				err = "codepoint is out of range"
				errPos = pos
				return ""
			else
				return utf8.char(num)
			end
		end)
		:gsub("()\\(.)", function(pos, symbol)
			if not ESCAPES[symbol] then
				err = "invalid escape"
				errPos = pos
				return ""
			else
				return ESCAPES[symbol]
			end
		end)

	if not err then
		return cleaned, nil, nil
	else
		return nil, err, errPos
	end
end



local function isWhitespace(segment)
	return not segment:find("%S")
end

local function isCommentStart(segment)
	return charAt(segment, 1) == "#"
end

local function isStringStart(segment)
	return charAt(segment, 1) == "\""
end

local function isStringEnd(segment)
	return charAt(segment, #segment) == "\""
end

local function isStringStartAndEnd(segment)
	return isStringStart(segment) and isStringEnd(segment) and #segment > 1
end


local function matchNumber(segment)
	-- If the front of the number doesn't match, it's not a number literal.
	local base, trailing = segment:match("^([+-]?%d+)(.-)$")
	if not base then
		return nil, nil
	end

	-- Try to match a decimal. If it matches, update trailing. If it doesn't
	-- match, continue with exponent.
	local decimal, decimalTrailing = trailing:match("^(%.%d+)(.-)$")
	if decimal then
		trailing = decimalTrailing
	else
		decimal = ""
	end

	-- Try to match an exponent. If it doesn't match and trailing isn't empty,
	-- the number is malformed. Otherwise, continue.
	local exp = trailing:match("^[eE][+-]?%d+$")
	if not exp then
		if trailing ~= "" then
			return nil, "malformed number"
		end

		exp = ""
	end

	return Literal(tonumber(base .. decimal .. exp))
end

local function matchNil(segment)
	if segment == "nil" then
		return Literal(nil)
	else
		return nil, nil
	end
end

local function matchIdentifier(segment) -- Should be matched last
	if charAt(segment, 1):find(RESERVED_SET) or matchNil(segment) then
		return nil, nil
	else
		return Identifier(segment), nil
	end
end

local function matchRetrieval(segment)
	local retrievals, start = segment:match("^(@+)(.-)$")
	if not retrievals then
		return nil, nil
	elseif start == "" then
		return nil, "retrievals must specify a name"
	end

	-- Try matching a number
	local value, err = matchNumber(start)
	if err then
		return nil, "malformed number in retrieval name: " .. err
	end

	-- If a number doesn't match, try an identifier
	if not value then
		value, err = matchIdentifier(start)
		if err then
			return nil, "malformed identifier in retrieval name: " .. err
		end
	end

	if value then
		return Retrieval(value, #retrievals)
	else
		return nil, "invalid name in retrieval (must be a number or identifier)"
	end
end

local function matchBackRetrieval(segment)
	if segment == "<" then
		return BackRetrieval(), nil
	else
		return nil, nil
	end
end

local simpleMatchers = {
	matchNumber,
	matchNil,
	matchIdentifier,
	matchRetrieval,
	matchBackRetrieval,
}



local function segmentize(str)
	local segments = {}

	for segment1, segment2 in string.gmatch(str, "(%S*)(%s*)") do
		if segment1 ~= "" then
			table.insert(segments, segment1)
		end

		if segment2 ~= "" then
			table.insert(segments, segment2)
		end
	end

	return segments
end

local function parseSegments(segments)
	local tokens = {}
	local pos = 1
	local i = 1

	local function advance()
		pos = pos + #segments[i]
		i = i + 1
	end

	local function consume(token)
		table.insert(tokens, token)
		advance()
	end

	while i <= #segments do
		local segment = segments[i]
		if isWhitespace(segment) then -- Skip whitespace
			consume(nil)

		elseif isCommentStart(segment) then -- Finish on comments
			break

		elseif isStringStartAndEnd(segment) then -- Handle single-segment strings
			local str, err, pos2 = resolveString(segment)
			if not str then
				return nil, err, pos + pos2
			end

			consume(Literal(str))

		elseif isStringStart(segment) then -- Handle multi-segment strings
			local start = i
			local startPos = pos
			advance()

			-- Manually concatenate multiple segments
			while true do
				segment = segments[i]
				if not segment then
					return nil, "unterminated string", startPos
				end

				if isStringEnd(segment) then
					break
				else
					advance()
				end
			end

			local concatenated = table.concat(segments, "", start, i)
			local str, err, pos2 = resolveString(concatenated)
			if not str then
				return nil, err, pos + pos2
			end

			consume(Literal(str))

		else
			local matched = false

			for _, matcher in ipairs(simpleMatchers) do
				local token, err = matcher(segment)
				if err then
					return nil, err, pos
				elseif token then
					matched = true
					consume(token)
					break
				end
			end

			if not matched then
				return nil, "invalid token", pos
			end
		end
	end

	return tokens
end


local function parse(source)
	local tokens = {}

	local lineNum = 1
	for line in string.gmatch(source, "([^\r\n]*)\r?\n?") do
		local segments = segmentize(line)
		local lineTokens, err, pos = parseSegments(segments)

		if not lineTokens then
			return nil, pos .. ": " .. err
		elseif #lineTokens > 0 then
			lineTokens.lineNum = lineNum
			table.insert(tokens, lineTokens)
		end

		lineNum = lineNum + 1
	end

	return tokens
end



return {
	Literal = Literal,
	Identifier = Identifier,
	Retrieval = Retrieval,
	BackRetrieval = BackRetrieval,

	parse = parse,
}