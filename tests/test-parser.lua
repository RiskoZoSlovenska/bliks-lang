local parser = require("../parser")
local utils = require("./utils")

Literal = parser.Literal
Identifier = parser.Identifier
Retrieval = parser.Retrieval
BackRetrieval = parser.BackRetrieval


utils.test(parser.parse, {
	-- Numbers
	"34", { { Literal(34), lineNum = 1 } },
	"34.3", { { Literal(34.3), lineNum = 1 } },
	"34e2", { { Literal(3400), lineNum = 1 } },
	"34.3e2", { { Literal(3430), lineNum = 1 } },
	"34.3e-2", { { Literal(0.343), lineNum = 1 } },
	"-34", { { Literal(-34), lineNum = 1 } },
	"-34.3", { { Literal(-34.3), lineNum = 1 } },
	"-34e2", { { Literal(-3400), lineNum = 1 } },
	"-34.3e2", { { Literal(-3430), lineNum = 1 } },
	"-34.3e-2", { { Literal(-0.343), lineNum = 1 } },
	"+34", { { Literal(34), lineNum = 1 } },
	"+34.3", { { Literal(34.3), lineNum = 1 } },
	"+34e2", { { Literal(3400), lineNum = 1 } },
	"+34.3e2", { { Literal(3430), lineNum = 1 } },
	"+34.3e-2", { { Literal(0.343), lineNum = 1 } },

	-- Strings
	'"hello"', { { Literal("hello"), lineNum = 1 } },
	'"hello there"', { { Literal("hello there"), lineNum = 1 } },
	'"hello hi there nice"', { { Literal("hello hi there nice"), lineNum = 1 } },
	'"\\s\\q\\n\\t\\027\\u{1E240}"', { { Literal("\\\"\n\t\027\u{1E240}"), lineNum = 1 } },
	'"nil"', { { Literal("nil"), lineNum = 1 } },
	'"34"', { { Literal("34"), lineNum = 1 } },

	-- Nil
	"nil", { { Literal(nil), lineNum = 1 } },

	-- Identifiers
	"hello", { { Identifier("hello"), lineNum = 1 } },
	"hel-lo", { { Identifier("hel-lo"), lineNum = 1 } },
	"hell3o", { { Identifier("hell3o"), lineNum = 1 } },
	"e332.21", { { Identifier("e332.21"), lineNum = 1 } },
	"nill", { { Identifier("nill"), lineNum = 1 } },
	"nil1", { { Identifier("nil1"), lineNum = 1 } },
	">", { { Identifier(">"), lineNum = 1 } },
	"_", { { Identifier("_"), lineNum = 1 } },
	"_<>@#e2-32.1e2[2]", { { Identifier("_<>@#e2-32.1e2[2]"), lineNum = 1 } },

	-- Retrievals
	"@ohno", { { Retrieval(Identifier("ohno"), 1), lineNum = 1 } },
	"@@@ohno", { { Retrieval(Identifier("ohno"), 3), lineNum = 1 } },
	"@@@32", { { Retrieval(Literal(32), 3), lineNum = 1 } },
	"@@@+32.2e2", { { Retrieval(Literal(3220), 3), lineNum = 1 } },

	-- Back retrievals
	"<", { { BackRetrieval(), lineNum = 1 } },


	-- Multiple values
	'3 "hi"', { { Literal(3), Literal("hi"), lineNum = 1 } },
	'3 "hi there"', { { Literal(3), Literal("hi there"), lineNum = 1 } },
	'3 "hi there" 2', { { Literal(3), Literal("hi there"), Literal(2), lineNum = 1 } },
	'3 "hi there  " 2', { { Literal(3), Literal("hi there  "), Literal(2), lineNum = 1 } },
	'3 "  hi there  " 2', { { Literal(3), Literal("  hi there  "), Literal(2), lineNum = 1 } },
	'"hi there" 2', { { Literal("hi there"), Literal(2), lineNum = 1 } },

	'32.412e2 hello "hi" @cool', { { Literal(3241.2), Identifier("hello"), Literal("hi"), Retrieval(Identifier("cool"), 1), lineNum = 1 } },
	'> < @@>>', { { Identifier(">"), BackRetrieval(), Retrieval(Identifier(">>"), 2), lineNum = 1 } },

	-- Comments
	"", {},
	"# comment 5", {},
	"#comment 5", {},
	"   #    comment 5", {},
	" 3  #    comment", { { Literal(3), lineNum = 1 } },
	' "hello # there"  # comment 3', { { Literal("hello # there"), lineNum = 1 } },

	-- Multiple lines
	"3\n2", { { Literal(3), lineNum = 1 }, { Literal(2), lineNum = 2 } },
	"3\n\n2", { { Literal(3), lineNum = 1 }, { Literal(2), lineNum = 3 } },

	-- Empty
	
})

utils.testErr(parser.parse, {
	"231.", "1: malformed number",
	"231e", "1: malformed number",
	"231.2e", "1: malformed number",
	"  231.", "3: malformed number",

	'"hello', "1: unterminated string",
	'"hello there', "1: unterminated string",
	'"hi there" "hello   ', "12: unterminated string",

	'"he\\o"', "4: invalid escape",
	'"\\u{11FFFF}"', "2: codepoint is out of range",

	"@ hello", "1: retrievals must specify a name",
	"@-2.", "1: malformed number in retrieval name: malformed number",
	"@nil", "1: invalid name in retrieval (must be a number or identifier)",
	'@"hello"', "1: invalid name in retrieval (must be a number or identifier)",

	"<<", "1: invalid token",
	"-res", "1: invalid token",
	"'hi'", "1: invalid token",
})


print("Success!")