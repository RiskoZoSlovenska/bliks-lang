return {
	ValueType = {
		any = "any",
		string = "string",
		number = "number",
		pointer = "pointer",
		identifier = "identifier",
	},
	ArgumentType = {
		value = "value",
		retrieval = "retrieval",
	},
	TokenType = {
		identifier = "identifier",
		literal = "literal",
		retrieval = "retrieval",
		back_retrieval = "back_retrieval",
	},
	FunctionResult = {
		GOTO = "goto",
		WRITE = "write",
	},
	ParamType = {
		any = "a",
		string = "s",
		none = "v",
		number = "n",
		pointer = "p",
		identifier = "i",
	},
	ParsedType = {
		identifier = "id",
		literal = "lit",
		retrieval = "ret",
		backRetrieval = "bkret",
	},
	ResolvedType = {
		value = 0,
		retrieval = 1,
	},
}