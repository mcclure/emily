type value =
	| Null
	| FloatValue of float
	| StringValue of string
	| AtomValue   of string
	| BuiltinFunctionValue of (value -> value)
	| TableValue of (value, value) Hashtbl.t

