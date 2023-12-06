--[[= [standalone] fn parse
	Takes a source string and parses it into a list of instructions.

	@param string source
	@return {{Token}}? The parsed instructions, if successful.
	@return Error? A parsing error, if any.
]]

local enums = require("enums")
local structs = require("structs")

local TokenType = enums.TokenType

local Error = structs.Error
local Token = structs.Token

local Symbol = {
	whitespace = "[ \t\n]",
	lineBreak = "\n",
	instructionBreak = "[\n;:]",
	stringToggle = "\"",
	escape = "$",
	comment = "#",
	retrieval = "@",
	backRetrieval = "<",
	name = "[0-9a-zA-Z_%.!&%%>=]",
	numberStart = "[-+0-9]",
}

local escapes = {
	["$"] = "$",
	n = "\n",
	t = "\t",
	q = "\""
}

local function is(char, class)
	return char:find(class) ~= nil
end


local function RawToken(value, pos)
	return {
		value = value,
		pos = assert(pos),
	}
end


local function tokenize(source)
	local instructions = {}
	local curInstruction = {}
	local curToken = {}
	local curPos = 1
	local inString, inComment = false, false
	local expectingSpace = false

	local function pushToken()
		if #curToken == 0 then
			return
		end

		local value = table.concat(curToken)
		table.insert(curInstruction, RawToken(value, curPos - #value))
		curToken = {}
	end

	local function pushInstruction()
		if #curInstruction == 0 then
			return
		end

		table.insert(instructions, curInstruction)
		curInstruction = {}
	end

	local function processChar(char)
		-- Instruction break
		if not inString and is(char, Symbol.instructionBreak) then
			pushToken()
			pushInstruction()
			expectingSpace = false

		-- Whitespace
		elseif not inString and is(char, Symbol.whitespace) then
			pushToken()
			expectingSpace = false

		-- Comment
		elseif not inString and is(char, Symbol.comment) then
			pushToken()
			inComment = true
			expectingSpace = false

		-- Check expected space
		elseif expectingSpace then -- Not a space, comment or break at this point
			return Error("expected space", curPos)

		-- String toggle
		elseif is(char, Symbol.stringToggle) then
			if not inString and #curToken > 0 then
				return Error("invalid string start", curPos)
			end

			table.insert(curToken, char)
			inString = not inString

			if not inString then
				expectingSpace = true
			end

		-- Any other character
		else
			table.insert(curToken, char)
		end
	end

	for char in source:gsub("[^\n]$", "%0\n"):gmatch(".") do
		if is(char, Symbol.lineBreak) then
			if inString then
				return nil, Error("unterminated string", curPos - 1)
			end

			inComment = false
		end

		if not inComment then
			local err = processChar(char)

			if err then
				return nil, err
			end
		end

		curPos = curPos + 1
	end

	return instructions, nil
end

local function parseToken(token)
	assert(#token.value > 0)

	local firstChar = token.value:sub(1, 1)

	-- Retrieval
	if is(firstChar, Symbol.retrieval) then
		local depth, remainder = token.value:match("^(" .. Symbol.retrieval .. "+)(.-)$")
		if #assert(remainder) == 0 then
			return nil, Error("empty retrieval", token.pos)
		end

		local subRawToken = RawToken(remainder, token.pos + #depth)
		local subToken, err = parseToken(subRawToken)
		if not subToken then
			return nil, err
		end

		return Token(TokenType.retrieval, subToken, #depth, token.pos), nil

	-- Back Retrieval
	elseif is(firstChar, Symbol.backRetrieval) then
		if #token.value > 1 then
			return nil, Error("malformed back retrieval '%s'", token.pos, token.value)
		end

		return Token(TokenType.backRetrieval, nil, nil, token.pos), nil

	-- String literal
	elseif is(firstChar, Symbol.stringToggle) then
		local err, errPos = nil, nil
		local cleaned = token.value
			:sub(2, -2)
			:gsub(Symbol.escape .. "(%x%x)", function(hex)
				return string.char(tonumber(hex, 16))
			end)
			:gsub(Symbol.escape .. "()(.?)", function(pos, char)
				if escapes[char] then
					return escapes[char]
				else
					err = "invalid escape '" .. char .. "'"
					errPos = pos
				end
			end)

		if err then
			return nil, Error(err, token.pos + errPos)
		end

		return Token(TokenType.literal, cleaned, nil, token.pos), nil

	-- Number-like literal
	elseif is(firstChar, Symbol.numberStart) then
		local num = tonumber(token.value)
		if not num then
			return nil, Error("malformed number '%s'", token.pos, token.value)
		end

		return Token(TokenType.literal, num, nil, token.pos), nil

	-- Name
	else
		local invalid = token.value:gsub(Symbol.name, ""):sub(1, 1)
		if #invalid > 0 then
			return nil, Error("illegal character '%s' in name '%s'", token.pos, invalid, token.value)
		end

		return Token(TokenType.name, token.value, nil, token.pos), nil
	end
end


return function(source)
	local rawInstructions, tokenizeErr = tokenize(source)
	if not rawInstructions then
		return nil, tokenizeErr
	end

	local instructions = {}
	for _, rawInstruction in ipairs(rawInstructions) do
		local instruction = {}

		for _, rawToken in ipairs(rawInstruction) do
			local token, tokenErr = parseToken(rawToken)
			if not token then
				return nil, tokenErr
			end

			table.insert(instruction, token)
		end

		table.insert(instructions, instruction)
	end

	return instructions
end
