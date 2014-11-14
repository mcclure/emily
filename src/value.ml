type tableValue = (value, value) Hashtbl.t

and value =
	| Null
	| FloatValue of float
	| StringValue of string
	| AtomValue   of string
	| BuiltinFunctionValue of (value -> value)          (* function argument = result *)
	| BuiltinMethodValue of   (value -> value -> value) (* function self argument = result *)
	| TableValue of tableValue
