local function tableCompare(tbl1, tbl2, recursive)
	local checked = {}

	for key, value1 in pairs(tbl1) do
		local value2 = tbl2[key]

		if value2 ~= value1 then
			local bothTables = (type(value1) == "table") and (type(value2) == "table")

			if not bothTables or (recursive and not tableCompare(value1, value2, recursive)) then
				return false
			end
		end

		checked[key] = true
	end

	-- Check if tbl2 contains any keys that we have not found in tbl1
	for key in pairs(tbl2) do
		if not checked[key] then
			return false
		end
	end

	return true
end


local function test(func, cases)
	for i = 1, #cases, 2 do
		local str, expected = cases[i], cases[i + 1]

		local res, err = func(str)
		if not res then
			error(string.format("case %d ('%s'): %s", i, str, err))
		end

		if not tableCompare(res, expected, true) then
			print(string.format("case %d ('%s')", i, str))
			print("Got:")
			p(res)
			print("Expected:")
			p(expected)
			error("didn't match", 0)
		end
	end
end

local function testErr(func, cases)
	for i = 1, #cases, 2 do
		local str, expected = cases[i], cases[i + 1]

		local res, err = func(str)
		if res then
			print(string.format("case %d ('%s')", i, str))
			print("Got:")
			p(res)
			print("Expected:")
			p(expected)
			error("didn't match", 0)
		end

		if err ~= expected then
			error(string.format("case %d ('%s') error: expected '%s', got '%s'", i, str, expected, err))
		end
	end
end


return {
	tableCompare = tableCompare,

	test = test,
	testErr = testErr,
}