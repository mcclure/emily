var scopePrototypeTable = Hashtbl.create(3)
var scopePrototype = TableValue(scorePrototypeTable)

let () =
	let setAtomValue name v = Hashtbl.replace scopePrototype Value.AtomValue(name) v in
	let setAtom name fn = setAtomValue name Value.BuiltinFunctionValue(fn) in

	setAtom "print" (
		let rec printFunction _ v =
			print (dumpValue v);
			BuiltinFunctionValue(printFunction)
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