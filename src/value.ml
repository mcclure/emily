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

and tableBlankKind =
    | TrueBlank (* Really, actually empty. Only used for snippet scopes. *)
    | NoSet     (* Has .has. Used for immutable builtin prototypes. *)
    | NoLet     (* Has .set. Used for "flat" expression groups. *)
    | WithLet   (* Has .let. Used for scoped groups. *)
    | BoxFrom of value option (* Has .parent and uses object literal rules. *)

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
