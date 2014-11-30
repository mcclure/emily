(* Data representation for a runtime value. *)

type tableValue = (value, value) Hashtbl.t

and closureValue = {
    code   : Token.codeSequence;
    scope  : value;
    scoped : bool;
    key    : string option;
}

and value =
    | Null
    | True
    | FloatValue of float
    | StringValue of string
    | AtomValue   of string
    | BuiltinFunctionValue of (value -> value)          (* function argument = result *)
    | BuiltinMethodValue   of (value -> value -> value) (* function self argument = result *)
    | ClosureValue of closureValue
    | TableValue of tableValue
    | TableSetValue of tableValue
    | TableLetValue of tableValue
    | TableHasValue of tableValue

type tableBlankKind = TrueBlank | NoLet | WithLet

let idGenerator = ref 0.0

let parentKeyString = "parent"
let parentKey = AtomValue parentKeyString
let idKeyString = "!id"
let idKey = AtomValue idKeyString

let tableGet table key = CCHashtbl.get table key
let tableSet table key value = Hashtbl.replace table key value
let tableHas table key = match tableGet table key with Some _ -> true | None -> false
let tableSetString table key value = tableSet table (AtomValue key) value
let tableBlank kind : tableValue =
    let t = Hashtbl.create(1) in (match kind with
        | TrueBlank -> ()
        | NoLet ->   tableSetString t "set" (TableSetValue t)
        | WithLet -> tableSetString t "set" (TableSetValue t); tableSetString t "let" (TableLetValue t)
    );
    tableSetString t "has" (TableHasValue t);
    if Options.(run.trackObjects) then idGenerator := !idGenerator +. 1.0; tableSet t idKey (FloatValue !idGenerator);
    t
let tableInheriting kind v =
    let t = tableBlank kind in tableSet t parentKey v;
        t

(* FIXME: This is no good because it will not take into account binding changes after the set is captured. *)
let tableBoundSet t key =
    let f value =
        tableSet t key value; Null
    in BuiltinFunctionValue(f)
let tableBoundHas t key =
    let f value =
        tableSet t key value; Null
    in BuiltinFunctionValue(f)

let boolCast v = if v then True else Null

let snippetScope bindings =
    let scopeTable = tableBlank TrueBlank in
    List.iter (fun x -> match x with (k,v) -> tableSet scopeTable (AtomValue k) v) bindings;
    TableValue(scopeTable)
