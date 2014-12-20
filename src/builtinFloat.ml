(* Populates a prototype for floats *)
let floatPrototypeTable = ValueUtil.tableInheriting Value.NoSet BuiltinTrue.truePrototype

let () =
    let (_, _, setAtomMethod) = BuiltinNull.atomFuncs floatPrototypeTable in

    let setAtomMath name f = setAtomMethod name (fun a b ->
        match (a,b) with
            | (Value.FloatValue f1, Value.FloatValue f2) -> Value.FloatValue( f f1 f2 )
            | (Value.FloatValue _, _) -> failwith "Don't know how to add that to a number"
            | _ -> failwith "Internal consistency error: Reached impossible place"
    ) in

    let setAtomTest name f = setAtomMethod name (fun a b ->
        match (a,b) with
            | (Value.FloatValue f1, Value.FloatValue f2) -> ValueUtil.boolCast( f f1 f2 )
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