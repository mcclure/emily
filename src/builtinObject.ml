(* Populates a prototype for objects *)
let objectPrototypeTable = ValueUtil.tableInheriting Value.NoSet BuiltinTrue.truePrototype
let objectPrototype = Value.TableValue(objectPrototypeTable)

(* TODO: Prototype for []s? .append can live in here. *)
let () =
    let (_, _, _) = BuiltinNull.atomFuncs objectPrototypeTable in

    ()
