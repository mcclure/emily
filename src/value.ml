type tableValue = (value, value) Hashtbl.t

and closureValue = {
	code  : Token.codeSequence;
	scope : value;
	key   : string option;
}

and value =
	| Null
	| FloatValue of float
	| StringValue of string
	| AtomValue   of string
	| BuiltinFunctionValue of (value -> value)          (* function argument = result *)
	| BuiltinMethodValue   of (value -> value -> value) (* function self argument = result *)
	| ClosureValue of closureValue
	| TableValue of tableValue
