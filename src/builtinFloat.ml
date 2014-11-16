let floatPrototypeTable = Hashtbl.create(3)

let () =
	let setAtomValue name v = Hashtbl.replace floatPrototypeTable (Value.AtomValue name) v in 
	let setAtomFn name fn = setAtomValue name (Value.BuiltinFunctionValue fn) in
	let setAtomMethod name fn = setAtomValue name (Value.BuiltinMethodValue fn) in

	let setAtomMath name f = setAtomMethod name (fun a b ->
		match (a,b) with
			| (Value.FloatValue f1, Value.FloatValue f2) -> Value.FloatValue( f f1 f2 )
            | (Value.FloatValue _, _) -> failwith "Don't know how to add that to a number"
            | _ -> failwith "Internal consistency error: Reached impossible place"
	) in

	let setAtomTest name f = setAtomMethod name (fun a b ->
		match (a,b) with
			| (Value.FloatValue f1, Value.FloatValue f2) -> Value.boolCast( f f1 f2 )
            | (Value.FloatValue _, _) -> failwith "Don't know how to compare that to a number"
            | _ -> failwith "Internal consistency error: Reached impossible place"
	) in

	setAtomMath "plus"   ( +. );
	setAtomMath "minus"  ( -. );
	setAtomMath "times"  ( *. );
	setAtomMath "divide" ( /. );

	setAtomTest "lt"     ( <  );
	setAtomTest "lte"    ( <= );
	setAtomTest "gt"     ( >  );
	setAtomTest "gte"    ( >= );
	setAtomTest "eq"     ( == );

	setAtomMethod "plus" (fun a b ->
		match (a,b) with
			| (Value.FloatValue f1, Value.FloatValue f2) -> Value.FloatValue( f1 +. f2 )
            | (Value.FloatValue _, _) -> failwith "Don't know how to add that to a number"
            | _ -> failwith "Internal consistency error: Reached impossible place"
	);
