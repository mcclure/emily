(* Populates a scope for use by snippets; the user can't ever see it. *)
(* Note: Scope does not inherit true because it isn't user accessible. *)
let privatePrototypeTable = ValueUtil.tableBlank Value.NoSet
let privatePrototype = Value.TableValue(privatePrototypeTable)

(* TODO *)

let () =
    let (_, _, _) = BuiltinNull.atomFuncs scopePrototypeTable in
    ()