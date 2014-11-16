let nullPrototypeTable = Hashtbl.create(3)

(* Returns setAtomValue,setAtomFn,setAtomMethod *)
let atomFuncs table = 
	let setValue name v = Hashtbl.replace table (Value.AtomValue name) v in 
	( setValue
	, (fun n fn -> setValue n (Value.BuiltinFunctionValue fn))
	, (fun n fn -> setValue n (Value.BuiltinMethodValue fn))
	)

(* FIXME: Making these *object methods* is a pretty bad approach and does not allow for expression short-circuiting *)
let () =
	let (_, setAtomFn, _) = atomFuncs nullPrototypeTable in

	setAtomFn "and" (fun v -> Value.boolCast false);
	setAtomFn "or"  (fun v -> Value.boolCast (match v with Value.Null -> false | _ -> true ));
	setAtomFn "xor" (fun v -> Value.boolCast (match v with Value.Null -> false | _ -> true ));
