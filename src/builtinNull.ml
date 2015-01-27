(* Populates a prototype for nulls, also holds machinery used by other Builtin files *)
let nullPrototypeTable = ValueUtil.tableBlank Value.NoSet

(* Returns setAtomValue,setAtomFn,setAtomMethod *)
let atomFuncs table =
    let setValue name v = Value.tableSet table (Value.AtomValue name) v in
    ( (setValue)
    , (fun n fn -> setValue n (Value.BuiltinFunctionValue fn))
    , (fun n fn -> setValue n (Value.BuiltinMethodValue fn))
    )

(* FIXME: Making these *object methods* is a pretty bad approach and does not allow for expression short-circuiting *)
let () =
    let (_, setAtomFn, _) = atomFuncs nullPrototypeTable in

    setAtomFn "eq"  (fun v -> ValueUtil.boolCast (match v with Value.Null -> true | _ -> false ));
