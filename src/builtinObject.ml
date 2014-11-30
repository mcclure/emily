(* Populates a prototype for objects *)
let objectPrototypeTable = Value.tableInheriting Value.TrueBlank BuiltinTrue.truePrototype
let objectPrototype = Value.TableValue(objectPrototypeTable)

let () =
    let (setAtomValue, setAtomFn, setAtomMethod) = BuiltinNull.atomFuncs objectPrototypeTable in

    ()
