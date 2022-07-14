local utils = require("./utils")

local parser = require("../parser")
local resolver = require("../resolver2")
local ctFunctions = require("../standard/compile-time-functions")
local rtFunctions = require("../standard/run-time-functions")
local enums = require("../enums")

local OPTIONS = {
	compileTimeFunctions = ctFunctions,
	runTimeFunctions = rtFunctions,
}

local RUNS = {
	read = rtFunctions.read[3],
	write = rtFunctions.write[3],
	jump = rtFunctions.jump[3],
	max = rtFunctions.max[3],
	add = rtFunctions.add[3],
}

local ValueType = enums.ValueType
local Value = resolver.Value
local Retrieval = resolver.Retrieval



local function resolve(source)
	local parsed = assert(parser.parse(source))
	return resolver.resolve(parsed, OPTIONS)
end

local function Program(labels, firstInstruction, ...)
	return {
		instructions = {...},
		firstInstruction = firstInstruction,

		labels = labels,
	}
end

local function Instruction(funcName, lineNum, ...)
	return {
		run = assert(RUNS[funcName]),
		args = {...},
		lineNum = lineNum,
	}
end



utils.test(resolve, {
	-- ____ "Basic",
	"read 1", Program({}, 1, Instruction("read", 1, Value(1)));
	"jump hello", Program({}, 1, Instruction("jump", 1, Value("hello")));
	"max 1 1 2", Program({}, 1, Instruction("max", 1, Value(1), Value(1), Value(2)));
	"max 1 1 2 3 4", Program({}, 1, Instruction("max", 1, Value(1), Value(1), Value(2), Value(3), Value(4)));
	"write 1", Program({}, 1, Instruction("write", 1, Value(1)));
	'write "hello"', Program({}, 1, Instruction("write", 1, Value("hello")));
	'write nil', Program({}, 1, Instruction("write", 1, Value(nil)));
	'add "2" 3 "4"', Program({}, 1, Instruction("add", 1, Value(2), Value(3), Value(4)));

	--____ "Empty",
	"", Program({}, 1),
	"\n\n\n", Program({}, 1),

	--____ "Retrievals",
	"read @1", Program({}, 1, Instruction("read", 1, Retrieval(1, 1, ValueType.pointer))),
	"read @@1", Program({}, 1, Instruction("read", 1, Retrieval(1, 2, ValueType.pointer))),

	--____ "Back retrievals",
	"add 4 < 1", Program({}, 1, Instruction("add", 1, Value(4), Retrieval(4, 1, ValueType.number), Value(1))),
	"add @@3 < 1", Program({}, 1, Instruction("add", 1, Retrieval(3, 2, ValueType.pointer), Retrieval(3, 3, ValueType.number), Value(1))),

	--____ "Multiple lines",
	"read 1\nread 2", Program({}, 1, Instruction("read", 1, Value(1)), Instruction("read", 2, Value(2))),
	"read 1\n\nread 2", Program({}, 1, Instruction("read", 1, Value(1)), Instruction("read", 3, Value(2))),

	--____ "Definitions",
	"define hi 34\nread hi", Program({}, 1, Instruction("read", 2, Value(34))),
	"define hi nil\nwrite hi", Program({}, 1, Instruction("write", 2, Value(nil))),
	"define hi 34\n define hello hi\nread hello", Program({}, 1, Instruction("read", 3, Value(34))),
	"define hi 34\n\nread hi", Program({}, 1, Instruction("read", 3, Value(34))),
	"define hi 34\n\nread @hi", Program({}, 1, Instruction("read", 3, Retrieval(34, 1, ValueType.pointer))),

	--____ "Labels",
	"> hi", Program({ hi = { 1 } }, 1),
	"> hi\n> hello", Program({ hi = { 1 }, hello = { 1 } }, 1),
	"> hi\n> hi\nread 1\n> hi", Program({ hi = { 1, 1, 2 } }, 1, Instruction("read", 3, Value(1))),
	"read 1\n> hi\nread 2", Program({ hi = { 2 } }, 1, Instruction("read", 1, Value(1)), Instruction("read", 3, Value(2))),
	"read 1\n> hi\n\n\n\n\nread 2", Program({ hi = { 2 } }, 1, Instruction("read", 1, Value(1)), Instruction("read", 7, Value(2))),

	--____ "Begins",
	"begin", Program({}, 1),
	"read 1\nbegin\nread 2", Program({}, 2, Instruction("read", 1, Value(1)), Instruction("read", 3, Value(2))),
	"read 1\n\n\n\n\nbegin\n\n\nread 2", Program({}, 2, Instruction("read", 1, Value(1)), Instruction("read", 9, Value(2))),

	--____ "Same identifiers",
	"define hello 3\n> hello\nread hello\njump hello", Program({ hello = { 1 } }, 1, Instruction("read", 3, Value(3)), Instruction("jump", 4, Value("hello"))),
})

utils.testErr(resolve, {
	-- Bad lines
	"3.2", "instruction must start with a function name",
	'"read"', "instruction must start with a function name",
	'nil', "instruction must start with a function name",
	"fusakgfdjgakj", "unknown function name",

	-- Num of args
	"max 1 1", "function expects at least 3 argument(s), but got 2",
	"read 1 1", "function expects at most 1 argument(s), but got 2",

	-- Types
	'read 3.2', "expected pointer, got number",
	'read "hi"', "expected pointer, got string",
	'read nil', "expected pointer, got any",
	"define nil nil", "expected identifier, got any",
	'jump "hi"', "expected identifier, got string",
	"jump @1", "retrieval cannot resolve to an identifier",

	-- Macros
	'read hi', "undefined macro",
	"define hello 3\ndefine hello 3", "cannot re-define macro 'hello'",

	-- Begins
	"begin\nbegin", "cannot define more than one beginning",

	-- Bad retrievals
	"define hi @1", "compile-time functions cannot use retrievals",
	"define hi <", "compile-time functions cannot use retrievals",
	"read <", "first argument must not be a back retrieval",
})



print("Success!")