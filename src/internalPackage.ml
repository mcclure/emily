let tablePair () =
    let table = ValueUtil.tableBlank Value.NoSet in
    let value = Value.TableValue(table) in
    table,value

(* Sign-of-divisor modulus *)
let modulus a b = mod_float ( (mod_float a b) +. b ) b

let internalTable,internalValue = tablePair()

let () =
    let setAtomValue  ?target:(table=internalTable) name v = Value.tableSet table (Value.AtomValue name) v in
    let setAtomFn     ?target:(table=internalTable) n fn = setAtomValue ~target:table n (Value.BuiltinFunctionValue fn) in
    let setAtomBinary ?target:(table=internalTable) n fn = setAtomValue ~target:table n @@ ValueUtil.snippetClosure 2 (function
        | [a;b] -> fn a b
        | _ -> ValueUtil.impossibleArg "<builtin-pair>") in
    let insertTable ?target:(table=internalTable) n =
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
    setAtomBinary "primitiveEq" (fun a b -> ValueUtil.boolCast ( (=) a b ));

    let outTable = insertTable "out" in
    setAtomFn ~target:outTable "print" @@ reusable (fun v -> print_string @@ Pretty.dumpValueForUser v);
    setAtomFn ~target:outTable "flush" @@ reusable (fun _ -> flush_all ());

    let doubleTable = insertTable "double" in

    let setAtomMath ?target:(table=doubleTable) name f = setAtomValue ~target:table name @@ ValueUtil.snippetClosure 2 (function
        | [Value.FloatValue f1;Value.FloatValue f2] -> Value.FloatValue( f f1 f2 )
        | [Value.FloatValue _; _] -> failwith "Don't know how to add that to a number"
        | _ -> failwith "Internal consistency error: Reached impossible place"
    ) in

    let setAtomTest ?target:(table=doubleTable) name f = setAtomValue ~target:table name @@ ValueUtil.snippetClosure 2 (function
        | [Value.FloatValue f1; Value.FloatValue f2] -> ValueUtil.boolCast( f f1 f2 )
        | [Value.FloatValue _; _] -> failwith "Don't know how to compare that to a number"
        | _ -> failwith "Internal consistency error: Reached impossible place"
    ) in

    setAtomMath "add"      ( +. );
    setAtomMath "subtract" ( -. );
    setAtomMath "multiply" ( *. );
    setAtomMath "divide"   ( /. );
    setAtomMath "modulus"  modulus;

    (* Do I really need all four comparators? *)
    setAtomTest "lessThan"         ( <  );
    setAtomTest "lessThanEqual"    ( <= );
    setAtomTest "greaterThan"      ( >  );
    setAtomTest "greaterThanEqual" ( >= );

    setAtomValue "thisTransplant" ValueUtil.rethisTransplant;
    setAtomValue "thisInit" ValueUtil.rethisAssignObjectDefinition;
    setAtomValue "thisFreeze" ValueUtil.rethisAssignObject;
    setAtomValue "thisUpdate" ValueUtil.rethisSuperFrom;

    (* TODO *)
    setAtomValue "setPropertyKey" @@ ValueUtil.snippetClosure 3 (function
        | _ -> Value.Null (* NO *)
    );

    ()
