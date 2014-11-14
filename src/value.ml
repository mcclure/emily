type tableValue = (value, value) Hashtbl.t

and value =
	| Null
	| FloatValue of float
	| StringValue of string
	| AtomValue   of string
	| BuiltinFunctionValue of (value -> value)
	| TableValue of tableValue
