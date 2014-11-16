type tableValue = (value, value) Hashtbl.t

and closureValue = {
	code  : Token.codeSequence;
	scope : value;
	key   : string option;
}

and value =
	| Null
	| True
	| FloatValue of float
	| StringValue of string
	| AtomValue   of string
	| BuiltinFunctionValue of (value -> value)          (* function argument = result *)
	| BuiltinMethodValue   of (value -> value -> value) (* function self argument = result *)
	| ClosureValue of closureValue
	| TableValue of tableValue

let parentKey = AtomValue "parent"
let tableMake () : tableValue = Hashtbl.create(1)
let tableGet table key = CCHashtbl.get table key
let tableSet table key value = Hashtbl.replace table key value
let tableSetString table key value = tableSet table (AtomValue key) value
let tableInheriting v =
	let t = tableMake() in tableSet t parentKey v;
		t

let boolCast v = if v then True else Null