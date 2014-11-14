var scopePrototypeTable = Hashtbl.create(3)
var scopePrototype = TableValue(scorePrototypeTable)

let () =
	let setAtomValue name v = Hashtbl.replace scopePrototype Value.AtomValue(name) v in
	let setAtom name fn = setAtomValue name Value.BuiltinFunctionValue(fn) in

	setAtom "print" (
		let rec printFunction _ v =
			match v with 
				| Null -> print "<null>"
				| FloatValue v -> print v
				| StringValue s -> print s
				| AtomValue s -> print s
				| BuiltinFunctionValue _ -> "<builtin>"
				| TableValue of tableValue -> "<map>"
			; BuiltinFunctionValue(printFunction)
		in printFunction
	);

	setAtomValue "nl" StringValue("\n");

	setAtom "set" (fun objectValue key ->
		match objectValue with
			| TableValue obj -> 
				BuiltinFunctionValue(
					fun _ value -> Hashtbl.replace obj key value; Value.Null
				)
			| _ -> failwith "Internal consistency error: Reached impossible place"
	);