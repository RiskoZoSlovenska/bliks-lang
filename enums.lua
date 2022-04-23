return {
	ParamType = {
		any = "a",
		string = "s",
		none = "v",
		number = "n",
		pointer = "p",
		identifier = "i",
	},
	ParsedType = {
		identifier = 0,
		literal = 1,
		retrieval = 2,
		backRetrieval = 4,
	},
	ResolvedType = {
		value = 0,
		retrieval = 1,
	},
	FunctionResult = {
		GOTO = "goto",
		WRITE = "write",
	}
}