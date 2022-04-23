local f = string.format


return {
	begin = {"", function(state)
		if state.firstInstruction or state.openFirstInstruction then
			return false, "cannot define more than one beginning"
		end
		state.openFirstInstruction = state.lineNum

		return true
	end},
	define = {"i a", function(state, name, literal)
		if state.macros[name] or state.nilmacros[name] then
			return false, f("cannot redefine macro %s", name)
		end

		if literal ~= nil then
			state.macros[name] = literal
		else
			state.nilmacros[name] = true
		end

		return true
	end},
	[">"] = {"i", function(state, name)
		state.openLabels[name] = true

		return true
	end},
}