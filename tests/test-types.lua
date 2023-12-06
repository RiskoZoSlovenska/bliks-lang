local types = require("types")
local structs = require("structs")
local enums = require("enums")

local Token = structs.Token
local TokenType = enums.TokenType
local T = enums.ValueType

local function Params(min, max, ...)
	return {
		min = min,
		max = max,
		...
	}
end

---@diagnostic disable: undefined-global
describe("the types module", function()
	it("should parse empty param strings", function()
		assert.are.same(Params(0, 0), types.parseParams(""))
		assert.are.same(Params(0, 0), types.parseParams("   "))
	end)

	it("should parse plain param strings", function()
		assert.are.same(Params(4, 4, T.pointer, T.number, T.string, T.name), types.parseParams("p n s N"))
		assert.are.same(Params(3, 3, T.pointer, T.pointer, T.pointer), types.parseParams("p p p"))
	end)

	it("should parse param strings with optional params", function()
		assert.are.same(Params(2, 4, T.pointer, T.number, T.string, T.name), types.parseParams("p n s? N?"))
		assert.are.same(Params(0, 1, T.string), types.parseParams("s?"))
	end)

	it("should parse param strings with a vararg param", function()
		assert.are.same(Params(0, math.huge, T.string), types.parseParams("s*"))
		assert.are.same(Params(2, math.huge, T.pointer, T.number, T.string), types.parseParams("p n s*"))
	end)

	it("should fail on malformed params", function()
		assert.has.error(function() types.parseParams("?") end, "malformed parameter '?'")
		assert.has.error(function() types.parseParams("s??") end, "malformed parameter 's??'")
		assert.has.error(function() types.parseParams("s**") end, "malformed parameter 's**'")
		assert.has.error(function() types.parseParams("s?*") end, "malformed parameter 's?*'")
		assert.has.error(function() types.parseParams("sp") end, "malformed parameter 'sp'")
		assert.has.error(function() types.parseParams("s-") end, "malformed parameter 's-'")
	end)

	it("should fail on unknown types", function()
		assert.has.error(function() types.parseParams("e") end, "unknown type 'e'")
	end)

	it("should disallow optional params in the middle", function()
		assert.has.error(function() types.parseParams("s s? s") end, "optional parameters must be the at end")
		assert.has.error(function() types.parseParams("s? s") end, "optional parameters must be the at end")
	end)

	it("should disallow non-trailing or duplicate varargs", function()
		assert.has.error(function() types.parseParams("s* s") end, "vararg parameter must be the last one")
		assert.has.error(function() types.parseParams("s* s*") end, "vararg parameter must be the last one")
	end)

	it("should correctly guess types of values", function()
		assert.are.equal(T.pointer, types.typeof(1))
		assert.are.equal(T.pointer, types.typeof(10))
		assert.are.equal(T.pointer, types.typeof("10.0"))
		assert.are.equal(T.pointer, types.typeof("10e4"))

		assert.are.equal(T.number, types.typeof(0))
		assert.are.equal(T.number, types.typeof(0.999999))
		assert.are.equal(T.number, types.typeof(0.5))
		assert.are.equal(T.number, types.typeof(-10))
		assert.are.equal(T.number, types.typeof(-10.2))
		assert.are.equal(T.number, types.typeof("-10.2"))

		assert.are.equal(T.string, types.typeof("-10.2e"))
		assert.are.equal(T.string, types.typeof("abcd"))
		assert.are.equal(T.string, types.typeof("--3"))
	end)

	it("should correctly guess types of tokens", function()
		assert.are.equal(T.name,    types.typeoftoken(Token(TokenType.name, "a", nil, 1)))
		assert.are.equal(T.string,  types.typeoftoken(Token(TokenType.literal, "a", nil, 1)))
		assert.are.equal(T.pointer, types.typeoftoken(Token(TokenType.literal, "10.0", nil, 1)))
		assert.are.equal(T.number,  types.typeoftoken(Token(TokenType.literal, "-10.2", nil, 1)))
		assert.are.equal(T.string,  types.typeoftoken(Token(TokenType.literal, "-10.2e", nil, 1)))
	end)

	it("should correctly identify subtypes and supertypes", function()
		assert.is_true(types.is(T.pointer, T.pointer))
		assert.is_true(types.is(T.pointer, T.string))
		assert.is_true(types.is(T.number, T.string))
		assert.is_true(types.is(T.string, T.string))
		assert.is_true(types.is(T.name, T.name))

		assert.is_false(types.is(T.name, T.string))
		assert.is_false(types.is(T.string, T.pointer))
		assert.is_false(types.is(T.number, T.pointer))
		assert.is_false(types.is(T.string, T.number))
	end)
end)
