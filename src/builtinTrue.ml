(* Populates a prototype for trues *)
let truePrototypeTable = ValueUtil.tableBlank Value.NoSet
let truePrototype = Value.TableValue(truePrototypeTable)

let () =
    let (_, setAtomFn, setAtomMethod) = BuiltinNull.atomFuncs truePrototypeTable in

    setAtomMethod "eq" (fun a b -> ValueUtil.boolCast ( (=) a b ));
