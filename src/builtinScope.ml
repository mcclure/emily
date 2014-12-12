(* Populates a prototype for scopes *)
(* Note: Scope does not inherit true because it isn't user accessible yet. *)
let scopePrototypeTable = Value.tableBlank Value.TrueBlank
let scopePrototype = Value.TableValue(scopePrototypeTable)

let rethis = Value.snippetClosure 2 (function
    | [Value.ClosureValue(a);b] -> Value.ClosureValue( Value.rethis a b )
    | _ -> failwith "Bad arguments to rethis")

let dethis = Value.snippetClosure 1 (function
    [Value.ClosureValue(a)] -> Value.ClosureValue( Value.dethis a )
    | _ -> failwith "Bad arguments to dethis")

let decontext = Value.snippetClosure 1 (function
    [Value.ClosureValue(a)] -> Value.ClosureValue( Value.decontext a )
    | _ -> failwith "Bad arguments to dethis")

let makeSuper current this = Value.snippetTextClosure 1
    ["rethis",rethis;"current",current;"obj",this]
    ["arg"]
    "(rethis obj (current.parent)) arg"

let () =
    let (setAtomValue, setAtomFn, setAtomMethod) = BuiltinNull.atomFuncs scopePrototypeTable in

    setAtomFn "print" (
        let rec printFunction v =
            print_string (Pretty.dumpValueForUser v);
            Value.BuiltinFunctionValue(printFunction)
        in printFunction
    );

    setAtomValue "ln" (Value.StringValue "\n");

    setAtomValue "null" (Value.Null);
    setAtomValue "true" (Value.True);

    setAtomFn "not" (fun v -> match v with Value.Null -> Value.True | _ -> Value.Null);

    setAtomFn "println" (
        let rec printFunction v =
            print_endline (Pretty.dumpValueForUser v);
            Value.BuiltinFunctionValue(printFunction)
        in printFunction
    );
