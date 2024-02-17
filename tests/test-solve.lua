local parse = require("parse")
local solve = require("solve")
local stdlib = require("stdlib")
local structs = require("structs")
local enums = require("enums")

local VT = enums.ValueType
local AT = enums.ArgumentType

local Error = structs.Error

local function Value(typ, value, pos)
	return structs.Argument(AT.value, typ, value, nil, pos)
end

local function Name(value, pos)    return Value(VT.name,    value, pos) end
local function Pointer(value, pos) return Value(VT.pointer, value, pos) end
local function Number(value, pos)  return Value(VT.number,  value, pos) end
local function String(value, pos)  return Value(VT.string,  value, pos) end

local function Retr(typ, value, depth, pos)
	return structs.Argument(AT.retrieval, typ, value, depth, pos)
end

local function Instr(func, num, pos, ...)
	return structs.Instruction(func, { ... }, num, pos)
end

local function parseSolve(str)
	return solve(parse(str), stdlib)
end


assert:set_parameter("TableFormatLevel", 6)

---@diagnostic disable: undefined-global
describe("the solver", function()
	it("should solve an empty program", function()
		assert.are.same({ instructions = {}, begin = 1 }, solve(parse(""), stdlib))
		assert.are.same({ instructions = {}, begin = 1 }, solve(parse("\n;;"), stdlib))
	end)

	it("should solve a valid program", function()
		assert.are.same({
			instructions = {
				Instr(stdlib.set, 1, 18, Pointer(3, 22), String(5, 24)),
				Instr(stdlib.max, 2, 34, Pointer(3, 38), Number(3, 40), Retr(VT.number, 3, 1, 42),
				                      Retr(VT.number, 3, 1, 45), Retr(VT.number, 6, 3, 47), Number(2, 52)),
			},
			begin = 2,
			std_labels = { nice = { 1 } },
		}, parseSolve('let a 3; > nice; set a 5; begin; max a a @a < @@@6 2'))

		assert.are.same({
			instructions = {
				Instr(stdlib.tonum, 1, 33, Pointer(3, 39), String("jump", 41)),
				Instr(stdlib.jump, 2, 47, Name("jump", 52)),
			},
			begin = 1,
			std_labels = { jump = { 3 } },
		}, parseSolve('let jump "jump"; let jump jump; tonum 3 jump; jump jump; > jump'))

		assert.are.same({
			instructions = {
				Instr(stdlib.add, 1, 1, Retr(VT.pointer, 1, 2, 5), Retr(VT.number, 1, 3, 9), Retr(VT.number, 1, 3, 11)),
			},
			begin = 1,
		}, parseSolve('add @@1 < <'))
	end)

	it("should reject instructions without a name", function()
		assert.are.same({nil, Error("expected instruction name, got a literal", 1)}, {parseSolve('3')})
		assert.are.same({nil, Error("expected instruction name, got a literal", 10)}, {parseSolve('let a 3; "hi" yes')})
		assert.are.same({nil, Error("expected instruction name, got a retrieval", 10)}, {parseSolve('let a 3; @a yes')})
		assert.are.same({nil, Error("expected instruction name, got a back retrieval", 10)}, {parseSolve('let a 3; < yes')})
	end)

	it("should reject unknown function names", function()
		assert.are.same({nil, Error("no such function 'addc'", 1)}, {parseSolve('addc')})
	end)

	it("should fail when functions are passed the wrong number of arguments", function()
		assert.are.same({nil, Error("function expects at least 3 argument(s), but got only 2", 1)}, {parseSolve('add 1 2')})
		assert.are.same({nil, Error("function expects at least 3 argument(s), but got only 0", 1)}, {parseSolve('sub')})
		assert.are.same({nil, Error("function expects at most 3 argument(s), but got 4", 1)}, {parseSolve('sub 1 2 3 4')})
	end)

	it("should fail when functions are passed the wrong types of arguments", function()
		assert.are.same(
			{nil, Error("function expects a pointer for argument 1, but got '3.2' (a number)", 5)},
			{parseSolve('add 3.2 3 3')}
		)
		assert.are.same(
			{nil, Error("function expects a pointer for argument 1, but got 'hi' (a string)", 5)},
			{parseSolve('add "hi" 3 3')}
		)
		assert.are.same(
			{nil, Error("function expects a name for argument 1, but got 'hi' (a string)", 6)},
			{parseSolve('jump "hi"')}
		)
		assert.are.same(
			{nil, Error("function expects a name for argument 1, but got a retrieval", 6)},
			{parseSolve('jump @3')}
		)
	end)

	it("should fail when retrievals end up with non-pointer values", function()
		assert.are.same(
			{nil, Error("retrieval (for argument 1) expects a pointer, but got '1.5' (a number)", 6)},
			{parseSolve('add @1.5 1 1')}
		)
		assert.are.same(
			{nil, Error("retrieval (for argument 2) expects a pointer, but got '1.5' (a number)", 11)},
			{parseSolve('tonum 1.5 <')}
		)
	end)

	it("should disallow retrievals in static functions", function()
		assert.are.same({nil, Error("argument 2 cannot be a retrieval", 8)}, {parseSolve('let hi @1')})
		-- assert.are.same({nil, Error("static function cannot use retrievals", 8)}, {parseSolve('x 1 <')}) -- No such func
	end)

	it("should disallow back retrievals that are also the first argument", function()
		assert.are.same({nil, Error("the first argument cannot be a back retrieval", 5)}, {parseSolve('add < 2 3')})
	end)

	it("should fail when given an undefined macro", function()
		assert.are.same({nil, Error("macro 'hi' is not defined", 15)}, {parseSolve('> hi; tonum 1 hi')})
	end)

	it("should disallow multiple begin statements", function()
		assert.are.same({nil, Error("beginning has already been defined", 8)}, {parseSolve('begin; begin')})
	end)
end)
