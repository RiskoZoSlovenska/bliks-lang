local expand = require("expand")
local enums = require("enums")
local structs = require("structs")

local VT = enums.ValueType
local AT = enums.ArgumentType

local Error = structs.Error

local function Retr(typ, value, depth, pos)
	return structs.Argument(AT.retrieval, typ, value, depth, pos)
end

local function Value(typ, value, pos)
	return structs.Argument(AT.value, typ, value, nil, pos)
end

local function Pointer(value, pos) return Value(VT.pointer, value, pos) end
local function Number(value, pos)  return Value(VT.number,  value, pos) end
local function String(value, pos)  return Value(VT.string,  value, pos) end


---@diagnostic disable: undefined-global
describe("the expand function", function()
	it("should not fail on an empty list", function()
		assert.are.same({}, expand({}))
	end)

	it("should expand literal values", function()
		assert.are.same({"a", 2, 10, "c"}, expand({ String("a", 1), Pointer("2.0", 2), Number("1e1", 3), String("c", 4) }))
	end)

	it("should expand retrievals", function()
		assert.are.same({3, "a", ""}, expand({
			Retr(VT.pointer, 2, 1, 1), Retr(VT.string, 2, 2, 2), Retr(VT.string, 4, 1, 3)
		}, {
			[2] = "3",
			[3] = "a",
		}))
	end)

	it("should error when retrievals don't expand to pointers mid-way", function()
		assert.are.same(
			{nil, Error("expected pointer during retrieval, but got '1' -> '2' -> 'b' (a string)", 1)},
			{expand({ Retr(VT.string, 1, 3, 1) }, {
				[1] = 2,
				[2] = "b",
				[3] = 4,
			})}
		)
		assert.are.same(
			{nil, Error("expected pointer during retrieval, but got '1' -> '2' -> '0' (a number)", 1)},
			{expand({ Retr(VT.string, 1, 3, 1) }, {
				[1] = 2,
				[2] = 0,
				[3] = 4,
			})}
		)
	end)

	it("should error when retrievals don't expand to their expected value", function()
		assert.are.same(
			{nil, Error("function expects a pointer for argument 1, but retrieval expanded to '1' -> '0' (a number)", 1)},
			{expand({ Retr(VT.pointer, 1, 1, 1) }, {
				[1] = 0,
			})}
		)
	end)
end)
