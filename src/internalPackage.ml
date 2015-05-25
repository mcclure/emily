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

    (* FIXME: At some point consolidate all these adhoc functions in one place. *)
    let internalFail () = failwith "Internal consistency error: Reached impossible place" in

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

    setAtomValue "thisTransplant" ValueUtil.rethisTransplant;
    setAtomValue "thisInit" ValueUtil.rethisAssignObjectDefinition;
    setAtomValue "thisFreeze" ValueUtil.rethisAssignObject;
    setAtomValue "thisUpdate" ValueUtil.rethisSuperFrom;

    setAtomValue "setPropertyKey" @@ ValueUtil.snippetClosure 3 (function
        | [Value.TableValue t;k;v] | [Value.ObjectValue t;k;v] ->
            Value.tableSet t k @@ Value.UserMethodValue v;
            Value.Null
        | [_;_;_] -> failwith "Attempted to call setPropertyKey on something other than an object"
        | _ -> internalFail ()
    );

    (* "Submodule" internal.out *)
    let outTable = insertTable "out" in
    setAtomFn ~target:outTable "print" @@ reusable (fun v -> print_string @@ Pretty.dumpValueForUser v);
    setAtomFn ~target:outTable "flush" @@ reusable (fun _ -> flush_all ());

    (* "Submodule" internal.double *)
    let doubleTable = insertTable "double" in

    let setAtomMath ?target:(table=doubleTable) name f = setAtomValue ~target:table name @@ ValueUtil.snippetClosure 2 (function
        | [Value.FloatValue f1;Value.FloatValue f2] -> Value.FloatValue( f f1 f2 )
        | [Value.FloatValue _; _] -> failwith "Don't know how to combine that with a number"
        | _ -> internalFail ()
    ) in

    let setAtomTest ?target:(table=doubleTable) name f = setAtomValue ~target:table name @@ ValueUtil.snippetClosure 2 (function
        | [Value.FloatValue f1; Value.FloatValue f2] -> ValueUtil.boolCast( f f1 f2 )
        | [Value.FloatValue _; _] -> failwith "Don't know how to compare that to a number"
        | _ -> internalFail ()
    ) in

    let setAtomMathFn ?target:(table=doubleTable) name f = setAtomFn ~target:table name @@ (function
        | Value.FloatValue f1 -> Value.FloatValue( f f1 )
        | _ -> failwith "Can only perform that function on a number"
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

    setAtomMathFn "floor"  floor;

    (* "Submodule" internal.type *)
    let typeTable = insertTable "type" in

    setAtomFn ~target:typeTable "isAtom"   (fun v -> match v with Value.AtomValue   _ -> Value.True | _ -> Value.Null);
    setAtomFn ~target:typeTable "isString" (fun v -> match v with Value.StringValue _ -> Value.True | _ -> Value.Null);
    setAtomFn ~target:typeTable "isNumber" (fun v -> match v with Value.FloatValue  _ -> Value.True | _ -> Value.Null);

    (* Done *)
    ()
