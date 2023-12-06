local utils = require("utils")
local structs = require("structs")

local Error = structs.Error

---@diagnostic disable: undefined-global
describe("the utilities", function()
	it("should truncate stuff intelligently", function()
		assert.are.same("1234567890123456...", utils.truncate("12345678901234567890"))
		assert.are.same("12345678901234567890", utils.truncate("12345678901234567890", 5))
		assert.are.same("...5678901234567890123456789012345...", utils.truncate("1234567890123456789012345678901234567890", 20))
	end)

	it("should not mangle values when truncating", function()
		assert.are.same("                ...", utils.truncate("                abcd             "))
	end)

	it("should format errors nicely", function()
		assert.are.same(
			"bliks: error: S:2: oh no\n\t...5678901234567890123456789012345...\n\t                  ^",
			utils.formatError(Error("oh no", 25), "abcd\n1234567890123456789012345678901234567890\nnice", "S")
		)
		assert.are.same(
			"bliks: error: S:3: oh no\n\t\n\t^",
			utils.formatError(Error("oh no", 3), "\n\n\n\n\n", "S")
		)
		assert.are.same(
			"bliks: error: S:2: oh no\n\thi\n\t^",
			utils.formatError(Error("oh no", 5), "\n\t  hi\t\n\n", "S")
		)
	end)
end)
