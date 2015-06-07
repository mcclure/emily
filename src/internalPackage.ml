let tablePair () =
    let table = ValueUtil.tableBlank Value.NoSet in
    let value = Value.TableValue(table) in
    table,value

(* Sign-of-divisor modulus *)
let modulus a b = mod_float ( (mod_float a b) +. b ) b

let truefnValue = Value.BuiltinFunctionValue(fun x -> Value.True)

let internalTable,internalValue = tablePair()


let fakeRegisterLocation name = Token.{fileName=Internal name;lineNumber=0;lineOffset=0}
let fakeRegisterFrom reg =
    Value.{register=reg;scope=Null;code=[]}

let () =
    let setAtomValue   ?target:(table=internalTable) name v = Value.tableSet table (Value.AtomValue name) v in
    let setAtomFn      ?target:(table=internalTable) n fn = setAtomValue ~target:table n (Value.BuiltinFunctionValue fn) in
    (* let setAtomHandoff ?target:(table=internalTable) n fn = setAtomValue ~target:table n (Value.BuiltinHandoffValue fn) in *)
    let setAtomBinary  ?target:(table=internalTable) n fn = setAtomValue ~target:table n @@ ValueUtil.snippetClosure 2 (function
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

    (* "Submodule" internal.string *)
    let stringTable = insertTable "string" in

    (* Note: Does NOT coerce into a type, f is of type f -> value *)
    let setAtomStringOp ?target:(table=stringTable) name f = setAtomValue ~target:table name @@ ValueUtil.snippetClosure 1 (function
        | [Value.StringValue f1] -> f f1
        | _ -> failwith "Can only perform that operation on a string"
    ) in

    let ucharToCodepoint u = Value.FloatValue (float_of_int u) in
    let ucharToString u = (
        let buffer = Buffer.create 1 in
        let enc = Uutf.encoder `UTF_8 @@ `Buffer buffer in
        ignore @@ Uutf.encode enc (`Uchar u);
        ignore @@ Uutf.encode enc `End;
        Value.StringValue(Buffer.contents buffer)
    ) in
    let iteratorValue filter str = (
        let loc = fakeRegisterLocation "internal.string.iterUtf8" in
        let decoder = Uutf.decoder ~encoding:`UTF_8 @@ `String(str) in
        Value.BuiltinHandoffValue(fun context stack fnat ->
            let f, at = fnat in
            let decoded = Uutf.decode decoder in
            match decoded with
                | `Uchar u ->
                    let result = filter u in
                    Execute.executeStep context @@
                           (fakeRegisterFrom @@ Value.PairValue (f,result,loc,loc))
                        ::((fakeRegisterFrom @@ Value.FirstValue(truefnValue,loc,loc))
                        ::stack)
                | _ -> Execute.returnTo context stack (Value.Null,loc)
        )
    ) in
    setAtomStringOp "iterUtf8"          (iteratorValue ucharToString);
    setAtomStringOp "iterUtf8Codepoint" (iteratorValue ucharToCodepoint);

    setAtomValue ~target:stringTable "concat" @@ ValueUtil.snippetClosure 2 (function
        | [Value.StringValue f1;Value.StringValue f2] -> Value.StringValue( f1 ^ f2 )
        | [Value.StringValue _; _] -> failwith "Don't know how to combine that with a string"
        | _ -> internalFail ()
    );

    (* "Submodule" internal.type *)
    let typeTable = insertTable "type" in

    setAtomFn ~target:typeTable "isAtom"   (fun v -> match v with Value.AtomValue   _ -> Value.True | _ -> Value.Null);
    setAtomFn ~target:typeTable "isString" (fun v -> match v with Value.StringValue _ -> Value.True | _ -> Value.Null);
    setAtomFn ~target:typeTable "isNumber" (fun v -> match v with Value.FloatValue  _ -> Value.True | _ -> Value.Null);

    (* Done *)
    ()
