type value =
	| Null
	| FloatValue of float
	| StringValue of string
	| AtomValue   of string
	| FunctionValue of (value -> value)
	| TableValue of (value, value) Hashtbl.t

