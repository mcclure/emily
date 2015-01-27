(* Populates a prototype for trues *)
let truePrototypeTable = ValueUtil.tableBlank Value.NoSet
let truePrototype = Value.TableValue(truePrototypeTable)

let () =
    let (_, setAtomFn, setAtomMethod) = BuiltinNull.atomFuncs truePrototypeTable in

    setAtomFn "and" (fun v -> ValueUtil.boolCast (match v with Value.Null -> false | _ -> true  ));
    setAtomFn "or"  (fun v -> ValueUtil.boolCast true);
    setAtomFn "xor" (fun v -> ValueUtil.boolCast (match v with Value.Null -> true  | _ -> false ));

    setAtomMethod "eq" (fun a b -> ValueUtil.boolCast ( (=) a b ));
