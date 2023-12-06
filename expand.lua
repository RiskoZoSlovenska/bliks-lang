--[[= [standalone] fn expandArgs
	Takes a list of arguments (and, if necessary, registers) and expands each
	argument, converts numbers, handles and checks retrievals.

	@param {Argument} args
	@param {integer:string}? registers Only required if `args` contains
	  retrievals.

	@return {string}? The raw expanded values, ready to be passed to functions.
	@return string? An error message if something went wrong.
]]

local types = require("types")
local enums = require("enums")
local structs = require("structs")
local utils = require("utils")

local ArgumentType = enums.ArgumentType
local ValueType = enums.ValueType

local Error = structs.Error


local function formatTrace(trace)
	return table.concat(trace, " -> ")
end

local function formatTraceItem(item)
	return "'" .. utils.truncate(item) .. "'"
end

-- Follow retrieval, checking types and building a trace of values
local function expandRetrieval(arg, registers)
	local cur = arg.value
	local trace = { [1] = formatTraceItem(cur) }

	for i = 1, arg.depth do
		-- Check intermediate values are pointers
		local actual = types.typeof(cur)
		if not types.is(actual, ValueType.pointer) then
			return nil, trace, Error(
				"expected %s during retrieval, but got %s (a %s)", arg.pos,
				ValueType.pointer, formatTrace(trace), actual
			)
		end

		cur = registers[tonumber(cur)] or "" -- Need the tonumber since coercion doesn't happen with hashing
		trace[i + 1] = formatTraceItem(cur)
	end

	return cur, trace, nil
end

return function(args, registers)
	local expanded = {}

	for i, arg in ipairs(args) do
		if arg.type == ArgumentType.value then
			-- No retrieval required
			expanded[i] = arg.value
		else
			-- Retrieve
			local value, trace, retrievalErr = expandRetrieval(arg, assert(registers))
			if not value then
				return nil, retrievalErr
			end

			-- Check is expected
			local actual = types.typeof(value)
			if not types.is(actual, arg.expected) then
				return nil, Error(
					"function expects a %s for argument %d, but retrieval expanded to %s (a %s)", arg.pos,
					arg.expected, i, formatTrace(trace), actual
				)
			end

			expanded[i] = value
		end
	end

	-- Cast strings to numbers if numbers are expected
	for i, arg in ipairs(expanded) do
		if types.is(args[i].expected, ValueType.number) then
			expanded[i] = assert(tonumber(arg))
		end
		-- Perhaps strings should be casted as well?
	end

	return expanded, nil
end
