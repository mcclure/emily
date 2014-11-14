var floatPrototypeTable = Hashtbl.create(3)

let () =
	let setAtomValue name v = Hashtbl.replace scopePrototype Value.AtomValue(name) v in
	let setAtom name fn = setAtomValue name Value.BuiltinFunctionValue(fn) in

	setAtom "plus" (fun objectValue key ->
		match objectValue with
			| FloatValue f1 -> 
				BuiltinFunctionValue(
					fun _ value ->
						match value with
							| FloatValue f2 -> FloatValue( f1 + f2 )
							| _ -> failwith "Don't know how to add that to a number"
				)
			| _ -> failwith "Internal consistency error: Reached impossible place"
	);