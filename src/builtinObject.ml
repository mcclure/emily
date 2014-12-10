(* Populates a prototype for objects *)
let objectPrototypeTable = Value.tableInheriting Value.TrueBlank BuiltinTrue.truePrototype
let objectPrototype = Value.TableValue(objectPrototypeTable)

let () =
    let (_, _, _) = BuiltinNull.atomFuncs objectPrototypeTable in

    ()
