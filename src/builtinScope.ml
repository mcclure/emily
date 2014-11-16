let scopePrototypeTable = Hashtbl.create(3)
let scopePrototype = Value.TableValue(scopePrototypeTable)

let () =
	let (setAtomValue, setAtomFn, setAtomMethod) = BuiltinNull.atomFuncs scopePrototypeTable in
	
	setAtomFn "print" (
		let rec printFunction v =
			print_string (Pretty.dumpValue v);
			Value.BuiltinFunctionValue(printFunction)
		in printFunction
	);

	setAtomValue "nl" (Value.StringValue "\n");

	setAtomValue "null" (Value.Null);
	setAtomValue "true" (Value.True);

	setAtomFn "not" (fun v -> match v with Value.Null -> Value.True | _ -> Value.Null);

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
