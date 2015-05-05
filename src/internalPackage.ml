let internalTable = ValueUtil.tableBlank Value.NoSet
let internalValue = Value.TableValue(internalTable)

let () =
    let table = internalTable in
    let setAtomValue name v = Value.tableSet table (Value.AtomValue name) v in
    let setAtomFn n fn = setAtomValue n (Value.BuiltinFunctionValue fn) in

    setAtomValue "tern" ValueUtil.rawTern;
    setAtomValue "true" Value.True;

    setAtomFn "not"  (fun v -> match v with Value.Null -> Value.True | _ -> Value.Null);