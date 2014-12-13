(* Data representation for a runtime value. *)

type tableValue = (value, value) Hashtbl.t

(* Closure types: *)
and closureExecUser = {
    code   : Token.codeSequence;
    scoped : bool; (* Should the closure execution get its own let scope? *)
    scope  : value; (* Context scope *)
    (* Another option would be to make the "new" scope early & excise 'key': *)
    key    : string list; (* Not-yet-curried keys, or [] as special for "this is nullary" -- BACKWARD, first-applied key is last *)
}

and closureExec =
    | ClosureExecUser of closureExecUser
    | ClosureExecBuiltin of (value list -> value)

and closureThis =
    | Blank
    | Current of value
    | CurrentThis of value*value

(* Is this getting kind of complicated? Should curry be wrapped closures? *)
and closureValue = {
    exec   : closureExec;
    needArgs : int;  (* Count this down as more values are added to bound *)
    needThis : bool; (* This will always be true if closureExecUser is present. *)
    bound  : value list;   (* Already-curried values -- BACKWARD, first application last *)
    this   : closureThis; (* Tracks the "current" and "this" bindings *)
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

and tableBlankKind = TrueBlank | NoLet | WithLet | BoxFrom of value option

let idGenerator = ref 0.0

let parentKeyString = "parent"
let parentKey = AtomValue parentKeyString
let idKeyString = "!id"
let idKey = AtomValue idKeyString
let currentKeyString = "current"
let currentKey = AtomValue currentKeyString
let thisKeyString = "this"
let thisKey = AtomValue thisKeyString
let superKeyString = "super"
let superKey = AtomValue superKeyString

let tableGet table key = CCHashtbl.get table key
let tableSet table key value = Hashtbl.replace table key value
let tableHas table key = match tableGet table key with Some _ -> true | None -> false
let tableSetString table key value = tableSet table (AtomValue key) value
let rec tableBlank kind : tableValue =
    let t = Hashtbl.create(1) in (match kind with
        | TrueBlank -> ()
        | NoLet ->   tableSetString t "set" (TableSetValue t)
        | WithLet -> tableSetString t "set" (TableSetValue t); tableSetString t "let" (TableLetValue t)
        | BoxFrom parent -> let box = match parent with None -> tableBlank WithLet | Some value -> tableInheriting WithLet value in
             tableSetString t "set" (TableSetValue t); tableSetString t "let" (TableLetValue box); (* TODO: Fancier *)
             tableSet t currentKey (TableValue box)
    );
    tableSetString t "has" (TableHasValue t);
    if Options.(run.trackObjects) then idGenerator := !idGenerator +. 1.0; tableSet t idKey (FloatValue !idGenerator);
    t
and tableInheriting kind v =
    let t = tableBlank kind in tableSet t parentKey v;
        t

let boolCast v = if v then True else Null

let snippetScope bindings =
    let scopeTable = tableBlank TrueBlank in
    List.iter (fun x -> match x with (k,v) -> tableSet scopeTable (AtomValue k) v) bindings;
    TableValue(scopeTable)

(* Okay this is complicated *)

let recontext r current this = { r with this=CurrentThis(current, this) }

let decontext r = { r with this=Blank }

let dethis r = { r with this=match r.this with
    | CurrentThis (current,_) -> Current current
    | okay -> okay
}

let rethis this r = { r with this=match r.this with
    | Blank -> CurrentThis(this,this)
    | Current current -> CurrentThis(current, this)
    | CurrentThis (current,_) -> CurrentThis(current, this)
}

let snippetClosure argCount exec =
    ClosureValue({ exec = ClosureExecBuiltin(exec); needArgs = argCount;
        needThis = false; bound = []; this = Blank; })

let snippetTextClosure context keys text =
    ClosureValue({ exec = ClosureExecUser({code = Tokenize.snippet text; scope=snippetScope context;
        scoped = false; key = keys;
    }); needArgs = List.length keys;
        needThis = false; bound = []; this = Blank; })
