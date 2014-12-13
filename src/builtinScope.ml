(* Populates a prototype for scopes *)
(* Note: Scope does not inherit true because it isn't user accessible yet. *)
let scopePrototypeTable = Value.tableBlank Value.TrueBlank
let scopePrototype = Value.TableValue(scopePrototypeTable)

let rethis = Value.snippetClosure 2 (function
    | [a;Value.ClosureValue(b)] -> Value.ClosureValue( Value.rethis a b )
    | [a;b] -> failwith ("Bad argument to rethis: Need closure, got " ^ Pretty.dumpValue(b))
    | _ -> failwith ("Internal failure: Impossible argument to rethis"))

let dethis = Value.snippetClosure 1 (function
    | [Value.ClosureValue(a)] -> Value.ClosureValue( Value.dethis a )
    | _ -> failwith "Bad arguments to dethis")

let decontext = Value.snippetClosure 1 (function
    [Value.ClosureValue(a)] -> Value.ClosureValue( Value.decontext a )
    | _ -> failwith "Bad arguments to dethis")

let makeSuper current this = Value.snippetTextClosure
    ["rethis",rethis;"callCurrent",current;"obj",this]
    ["arg"]
    "(rethis obj (callCurrent.parent arg))"

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

    setAtomValue "rethis" rethis;

    setAtomFn "not" (fun v -> match v with Value.Null -> Value.True | _ -> Value.Null);

    setAtomFn "println" (
        let rec printFunction v =
            print_endline (Pretty.dumpValueForUser v);
            Value.BuiltinFunctionValue(printFunction)
        in printFunction
    );
