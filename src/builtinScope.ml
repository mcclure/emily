(* Populates a prototype for scopes *)
(* Note: Scope does not inherit true because it isn't user accessible yet. *)
let scopePrototypeTable = ValueUtil.tableBlank Value.NoSet
let scopePrototype = Value.TableValue(scopePrototypeTable)

let doConstruct = ValueUtil.snippetTextClosure (Token.Internal "do")
    ["null", Value.Null]
    ["f"]
    "f null"

let nullfn = ValueUtil.snippetTextClosure (Token.Internal "nullfn")
    ["null", Value.Null]
    []
    "^(null)"

let loop = ValueUtil.snippetTextClosure (Token.Internal "loop")
    ["tern", ValueUtil.tern; "null", Value.Null]
    ["f"]
    "{let .loop ^f ( tern (f null) ^(loop f) ^(null) ); loop} f" (* FIXME: This is garbage *)

let ifConstruct = ValueUtil.snippetTextClosure (Token.Internal "if")
    ["tern", ValueUtil.tern; "null", Value.Null]
    ["predicate"; "body"]
    "{let .if ^condition body (
        tern condition ^(body null) ^(null) );
    if} predicate body" (* Garbage construct again *)

let whileConstruct = ValueUtil.snippetTextClosure (Token.Internal "while")
    ["tern", ValueUtil.tern; "null", Value.Null]
    ["predicate"; "body"]
    "{let .while ^predicate body (
        tern (predicate null) ^(body null; while predicate body) ^(null)
    ); while} predicate body" (* Garbage construct again *)

(* and, or, xor take two fn args and return results on true *)
let andConstruct = ValueUtil.snippetTextClosure (Token.Internal "and")
    ["tern", ValueUtil.tern; "null", Value.Null]
    ["a"; "b"]
    "tern (a null) b ^(null)"

let orConstruct = ValueUtil.snippetTextClosure (Token.Internal "or")
    ["tern", ValueUtil.tern; "null", Value.Null]
    ["a"; "b"]
    "{ let .aValue (a null); tern aValue ^(aValue) b }"

let xorConstruct = ValueUtil.snippetTextClosure (Token.Internal "xor")
    ["rawTern", ValueUtil.rawTern; "null", Value.Null]
    ["a"; "b"]
    "{ let .aValue (a null); let .bValue (b null); rawTern aValue (
        rawTern bValue null aValue
    ) bValue }"

let () =
    let (setAtomValue, setAtomFn, setAtomMethod) = BuiltinNull.atomFuncs scopePrototypeTable in

    setAtomFn "print" (
        let rec printFunction v =
            print_string (Pretty.dumpValueForUser v);
            Value.BuiltinFunctionValue(printFunction)
        in printFunction
    );

    setAtomValue "sp" (Value.StringValue " ");
    setAtomValue "ln" (Value.StringValue "\n");

    setAtomValue "null" (Value.Null);
    setAtomValue "true" (Value.True);

    setAtomValue "tern"   ValueUtil.tern;
    setAtomValue "nullfn" nullfn;
    setAtomValue "do"     doConstruct;
    setAtomValue "loop"   loop;
    setAtomValue "if"     ifConstruct;
    setAtomValue "while"  whileConstruct;
    setAtomValue "and"    andConstruct;
    setAtomValue "or"     orConstruct;
    setAtomValue "xor"    xorConstruct;

    setAtomFn "not" (fun v -> match v with Value.Null -> Value.True | _ -> Value.Null);

    setAtomFn "println" (
        let rec printFunction v =
            print_endline (Pretty.dumpValueForUser v);
            Value.BuiltinFunctionValue(printFunction)
        in printFunction
    );

    setAtomValue "thisTransplant" ValueUtil.rethisTransplant;
    setAtomValue "thisInit" ValueUtil.rethisAssignObjectDefinition;
    setAtomValue "thisFreeze" ValueUtil.rethisAssignObject;
    setAtomValue "thisUpdate" ValueUtil.rethisSuperFrom;
