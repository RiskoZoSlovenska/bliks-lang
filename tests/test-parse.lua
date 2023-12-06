local parse = require("parse")
local enums = require("enums")
local structs = require("structs")

local TokenType = enums.TokenType
local Token = structs.Token
local Error = structs.Error

assert:set_parameter("TableFormatLevel", 5)


---@diagnostic disable: undefined-global
describe("the parser", function()
	it("should parse the empty strings", function()
		assert.are.same({}, parse(""))
		assert.are.same({}, parse("   "))
		assert.are.same({}, parse("\n\n\n"))
		assert.are.same({}, parse(";;;;"))
	end)

	it("should parse number literals", function()
		assert.are.same({{ Token(TokenType.literal, 123, nil, 1) }}, parse("123"))
		assert.are.same({{ Token(TokenType.literal, -123, nil, 1) }}, parse("-123"))
		assert.are.same({{ Token(TokenType.literal, 123.05, nil, 1) }}, parse("123.05"))
		assert.are.same({{ Token(TokenType.literal, -123.05, nil, 1) }}, parse("-123.05"))
		assert.are.same({{ Token(TokenType.literal, 123.05e2, nil, 1) }}, parse("123.05e2"))
		assert.are.same({{ Token(TokenType.literal, -123.05e2, nil, 1) }}, parse("-123.05e2"))
		assert.are.same({{ Token(TokenType.literal, 123.05e-2, nil, 1) }}, parse("123.05e-2"))
		assert.are.same({{ Token(TokenType.literal, -123.05e-2, nil, 1) }}, parse("-123.05e-2"))
		assert.are.same({{ Token(TokenType.literal, 123.05e+2, nil, 1) }}, parse("123.05e+2"))
		assert.are.same({{ Token(TokenType.literal, -123.05e+2, nil, 1) }}, parse("-123.05e+2"))
		assert.are.same({{ Token(TokenType.literal, -123.3e-2, nil, 1) }}, parse("-123.3e-2"))
		assert.are.same({{ Token(TokenType.literal, 123.3e-2, nil, 1) }}, parse("+123.3e-2"))
		assert.are.same({{ Token(TokenType.literal, 0.5, nil, 1) }}, parse("0.5"))
		assert.are.same({{ Token(TokenType.literal, 0.5, nil, 1) }}, parse("+.5"))
		assert.are.same({{ Token(TokenType.literal, -0.5, nil, 1) }}, parse("-.5"))
	end)

	it("should fail on malformed numbers", function()
		assert.are.same({nil, Error("malformed number '0a'", 1)}, {parse("0a")})
		assert.are.same({nil, Error("malformed number '0.4.2'", 1)}, {parse("0.4.2")})
		assert.are.same({nil, Error("malformed number '0.4ee'", 1)}, {parse("0.4ee")})
		assert.are.same({nil, Error("malformed number '--1'", 1)}, {parse("--1")})
		assert.are.same({nil, Error("malformed number '-.'", 1)}, {parse("-.")})
		assert.are.same({nil, Error("malformed number '+.'", 1)}, {parse("+.")})
	end)

	it("should parse string literals", function()
		assert.are.same({{ Token(TokenType.literal, "hi", nil, 1) }}, parse('"hi"'))
		assert.are.same({{ Token(TokenType.literal, "hi", nil, 1) }}, parse('"hi"\n\n'))
		assert.are.same({{ Token(TokenType.literal, "hi there", nil, 1) }}, parse('"hi there"'))
		assert.are.same({{ Token(TokenType.literal, " hi there ", nil, 1) }}, parse('" hi there "'))
		assert.are.same({{ Token(TokenType.literal, "  ", nil, 1) }}, parse('"  "'))
		assert.are.same({{ Token(TokenType.literal, "", nil, 1) }}, parse('""'))
		assert.are.same({{ Token(TokenType.literal, ";#", nil, 1) }}, parse('";#"'))
		assert.are.same({{ Token(TokenType.literal, "'", nil, 1) }}, parse('"\'"'))

		assert.are.same({{ Token(TokenType.literal, "$\n\u{1a}\t\"", nil, 1) }}, parse('"$$$n$1a$t$q"'))
	end)

	it("should fail on unterminated strings", function()
		assert.are.same({nil, Error("unterminated string", 11)}, {parse('"why hel;lo')})
		assert.are.same({nil, Error("unterminated string", 8)}, {parse('"why hel\nlo')})
	end)

	it("should fail on strings not flanked by spaces", function()
		assert.are.same({nil, Error("expected space", 5)}, {parse('"hi"e')})
		assert.are.same({nil, Error("expected space", 3)}, {parse('"""')})

		assert.are.same({nil, Error("invalid string start", 3)}, {parse('ee"hi"')})
		assert.are.same({nil, Error("invalid string start", 2)}, {parse('0"hi"')})
		assert.are.same({nil, Error("invalid string start", 2)}, {parse('0"hi"e')})
	end)

	it("should fail on invalid string escapes", function()
		assert.are.same({nil, Error("invalid escape 'e'", 3)}, {parse('"$e"')})
		assert.are.same({nil, Error("invalid escape ';'", 3)}, {parse('"$;"')})
		assert.are.same({nil, Error("invalid escape ''",  3)}, {parse('"$"')})
	end)

	it("should parse names", function()
		assert.are.same({{ Token(TokenType.name, "abcd", nil, 1) }}, parse("abcd"))
		assert.are.same({{ Token(TokenType.name, "...", nil, 1) }}, parse("..."))
		assert.are.same({{ Token(TokenType.name, ".124", nil, 1) }}, parse(".124"))
		assert.are.same({{ Token(TokenType.name, ".abCD092_.21", nil, 1) }}, parse(".abCD092_.21"))
		assert.are.same({{ Token(TokenType.name, "aA0123456789_.!&%>=", nil, 1) }}, parse("aA0123456789_.!&%>="))
	end)

	it("should fail on names containing illegal characters", function()
		assert.are.same({nil, Error("illegal character '-' in name 'ab-cd'", 1)}, {parse('ab-cd')})
		assert.are.same({nil, Error("illegal character '@' in name 'ab@cd'", 1)}, {parse('ab@cd')})
		assert.are.same({nil, Error("illegal character '<' in name 'ab<cd'", 1)}, {parse('ab<cd')})
		assert.are.same({nil, Error("illegal character '(' in name 'ab(cd'", 1)}, {parse('ab(cd')})
	end)

	it("should parse retrievals", function()
		assert.are.same({{ Token(TokenType.retrieval, Token(TokenType.name, "abcd", nil, 2), 1, 1) }}, parse("@abcd"))
		assert.are.same({{ Token(TokenType.retrieval, Token(TokenType.name, "abcd", nil, 4), 3, 1) }}, parse("@@@abcd"))
		assert.are.same({{ Token(TokenType.retrieval, Token(TokenType.literal, 123, nil, 2), 1, 1) }}, parse("@123"))
		assert.are.same({{ Token(TokenType.retrieval, Token(TokenType.literal, -123, nil, 2), 1, 1) }}, parse("@-123"))
		assert.are.same({{ Token(TokenType.retrieval, Token(TokenType.literal, 0.5, nil, 2), 1, 1) }}, parse("@0.5"))
	end)

	it("should fail on empty retrievals", function()
		assert.are.same({nil, Error("empty retrieval", 1)}, {parse('@')})
		assert.are.same({nil, Error("empty retrieval", 1)}, {parse('@@@')})
		assert.are.same({nil, Error("empty retrieval", 1)}, {parse('@#hhi')})
	end)

	it("should fail on malformed tokens in retrievals", function()
		assert.are.same({nil, Error("illegal character '@' in name 'ab@cd'", 2)}, {parse('@ab@cd')})
		assert.are.same({nil, Error("malformed number '1.1.1'", 2)}, {parse('@1.1.1')})
		assert.are.same({nil, Error("malformed number '1.1.1'", 4)}, {parse('@@@1.1.1')})
	end)

	it("should parse back retrievals", function()
		assert.are.same({{ Token(TokenType.backRetrieval, nil, nil, 1) }}, parse("<"))
	end)

	it("should fail on malformed back retrievals", function()
		assert.are.same({nil, Error("malformed back retrieval '<what'", 1)}, {parse('<what')})
		assert.are.same({nil, Error("malformed back retrieval '<-'", 1)}, {parse('<-')})
		assert.are.same({nil, Error("malformed back retrieval '<<'", 1)}, {parse('<<')})
	end)

	it("should parse comments", function()
		assert.are.same({}, parse("#"))
		assert.are.same({}, parse("# ab;cd"))
		assert.are.same({}, parse("# hello #there!! \n\n"))
	end)

	it("should parse comments following other tokens", function()
		assert.are.same({{ Token(TokenType.literal, -123.3e-2, nil, 1) }}, parse("-123.3e-2#hi"))
		assert.are.same({{ Token(TokenType.literal, "hi there", nil, 1) }}, parse('"hi there"#nice'))
		assert.are.same({{ Token(TokenType.name, "hi", nil, 1) }}, parse('hi#nice'))
		assert.are.same({{ Token(TokenType.retrieval, Token(TokenType.name, "ab", nil, 2), 1, 1) }}, parse("@ab#hi"))
		assert.are.same({{ Token(TokenType.backRetrieval, nil, nil, 1) }}, parse("<#"))
	end)


	it("should parse multiple tokens on the same line", function()
		assert.are.same({{
			Token(TokenType.literal, 123, nil, 1),
			Token(TokenType.name, "abcd", nil, 5),
			Token(TokenType.literal, "hi there", nil, 10),
			Token(TokenType.retrieval, Token(TokenType.name, "nice", nil, 22), 1, 21),
			Token(TokenType.backRetrieval, nil, nil, 27),
		}}, parse('123 abcd "hi there" @nice < # epic'))

		assert.are.same({{
			Token(TokenType.literal, " hi ", nil, 1),
			Token(TokenType.literal, " e ", nil, 8),
		}}, parse('" hi " " e "# "cool"'))
	end)

	it("should handle failures with multiple tokens on the same line", function()
		assert.are.same({nil, Error("malformed number '1.1.1'", 5)}, {parse('123 1.1.1')})
		assert.are.same({nil, Error("unterminated string", 14)}, {parse('"abc" 123 "def')})
	end)

	it("should handle multiple instructions per line", function()
		assert.are.same({
			{ Token(TokenType.literal, 123, nil, 1), Token(TokenType.literal, 456, nil, 5) },
			{ Token(TokenType.name, "abcd", nil, 9) },
			{ Token(TokenType.literal, "hi there", nil, 14) },
		}, parse('123 456;abcd:"hi there"# epic'))

		assert.are.same({
			{ Token(TokenType.literal, 123, nil, 1), Token(TokenType.literal, 456, nil, 5)  },
			{ Token(TokenType.name, "abcd", nil, 10) },
			{ Token(TokenType.literal, "hi there", nil, 17) },
		}, parse('123\t456; abcd ; "hi there";:;# epic'))
	end)

	it("should handle failures with multiple instructions on the same line", function()
		assert.are.same({nil, Error("malformed number '1.1.1'", 5)}, {parse('123;1.1.1')})
		assert.are.same({nil, Error("unterminated string", 12)}, {parse('"abc" ; "def')})
	end)

	it("should handle multiple lines", function()
		assert.are.same({
			{ Token(TokenType.literal, 123, nil, 1), Token(TokenType.literal, 456, nil, 5) },
			{ Token(TokenType.name, "abcd", nil, 9) },
			{ Token(TokenType.literal, "hi there", nil, 20) },
		}, parse('123 456\nabcd #epic\n"hi there"'))

		assert.are.same({
			{ Token(TokenType.literal, 123, nil, 1) },
			{ Token(TokenType.literal, 456, nil, 5) },
			{ Token(TokenType.name, "abcd", nil, 9) },
			{ Token(TokenType.literal, "hi there", nil, 20) },
		}, parse('123;456\nabcd #epic\n"hi there"'))
	end)

	it("should handle failures on multiple lines", function()
		assert.are.same({nil, Error("unterminated string", 11)}, {parse('"abcd"\n"def\n"egh')})
	end)
end)
