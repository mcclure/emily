let tablePair () =
    let table = ValueUtil.tableBlank Value.NoSet in
    let value = Value.TableValue(table) in
    table,value

let internalTable,internalValue = tablePair()

let () =
    let setAtomValue ?target:(table=internalTable) name v = Value.tableSet table (Value.AtomValue name) v in
    let setAtomFn    ?target:(table=internalTable) n fn = setAtomValue ~target:table n (Value.BuiltinFunctionValue fn) in
    let setAtomPair  ?target:(table=internalTable) n fn = setAtomValue ~target:table n @@ ValueUtil.snippetClosure 2 (function
        | [a;b] -> fn a b
        | _ -> ValueUtil.impossibleArg "<builtin-pair>") in
    let setTablePair ?target:(table=internalTable) n =
        let subTable,subValue = tablePair() in
        setAtomValue ~target:table n subValue;
        subTable
    in

    (* Create a function that consumes an argument, then returns itself. `fn` should return void *)
    let reusable fn =
        let rec inner arg =
            fn arg;
            Value.BuiltinFunctionValue(inner)
        in inner
    in

    setAtomValue "tern" ValueUtil.rawTern;
    setAtomValue "true" Value.True;

    setAtomFn "not"  (fun v -> match v with Value.Null -> Value.True | _ -> Value.Null);
    setAtomPair "primitiveEq" (fun a b -> ValueUtil.boolCast ( (=) a b ));

    let outTable = setTablePair "out" in

    setAtomFn ~target:outTable "print" @@ reusable (fun v -> print_string @@ Pretty.dumpValueForUser v);

    setAtomFn ~target:outTable "flush" @@ reusable (fun _ -> flush_all ());

    setAtomValue "thisTransplant" ValueUtil.rethisTransplant;
    setAtomValue "thisInit" ValueUtil.rethisAssignObjectDefinition;
    setAtomValue "thisFreeze" ValueUtil.rethisAssignObject;
    setAtomValue "thisUpdate" ValueUtil.rethisSuperFrom;

    ()
