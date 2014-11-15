let scopePrototypeTable = Hashtbl.create(3)
let scopePrototype = Value.TableValue(scopePrototypeTable)

let () =
	let setAtomValue name v = Hashtbl.replace scopePrototypeTable (Value.AtomValue name) v in 
	let setAtomFn name fn = setAtomValue name (Value.BuiltinFunctionValue fn) in
	let setAtomMethod name fn = setAtomValue name (Value.BuiltinMethodValue fn) in

	setAtomFn "print" (
		let rec printFunction v =
			print_string (Pretty.dumpValue v);
			Value.BuiltinFunctionValue(printFunction)
		in printFunction
	);

	setAtomValue "nl" (Value.StringValue "\n");

	setAtomFn "println" (
		let rec printFunction v =
			print_endline (Pretty.dumpValue v);
			Value.BuiltinFunctionValue(printFunction)
		in printFunction
	);

	setAtomMethod "set" (fun objectValue key ->
		match objectValue with
			| Value.TableValue obj -> 
				Value.BuiltinFunctionValue(
					fun value -> Hashtbl.replace obj key value; Value.Null
				)
			| _ -> failwith "Internal consistency error: Reached impossible place"
	);
