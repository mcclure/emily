let truePrototypeTable = Hashtbl.create(3)

let () =
	let (_, setAtomFn, _) = BuiltinNull.atomFuncs truePrototypeTable in

	setAtomFn "and" (fun v -> Value.boolCast (match v with Value.Null -> false | _ -> true  ));
	setAtomFn "or"  (fun v -> Value.boolCast true);
	setAtomFn "xor" (fun v -> Value.boolCast (match v with Value.Null -> true  | _ -> false ));
