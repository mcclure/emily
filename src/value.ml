type value =
	| Null
	| FloatValue of float
	| StringValue of string
	| AtomValue   of string
	| FunctionValue of (value -> value)

type valueMap = CCHashtbl.Make value