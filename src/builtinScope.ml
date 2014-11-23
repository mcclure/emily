(* Populates a prototype for scopes *)
let scopePrototypeTable = Value.tableBlank Value.TrueBlank
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
