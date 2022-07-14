return {
	begin = {"", function(program)
		if program.firstInstruction then
			return "cannot define more than one beginning"
		end
		program.firstInstruction = #program.instructions + 1
	end},
	define = {"i a", function(program, name, value)
		if program.macros[name] or program.nilmacros[name] then
			return string.format("cannot re-define macro '%s'", name)
		end

		if value ~= nil then
			program.macros[name] = value
		else
			program.nilmacros[name] = true
		end
	end},
	[">"] = {"i", function(program, name)
		if not program.labels[name] then
			program.labels[name] = {}
		end
		table.insert(program.labels[name], #program.instructions + 1)
	end},
}