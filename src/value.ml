(* Data representation for a runtime value. *)

type tableValue = (value, value) Hashtbl.t

(* Closure types: *)
and closureExecUser = {
    body     : Token.codeSequence;
    scoped   : bool;  (* Should the closure execution get its own let scope? *)
    envScope : value; (* Captured scope environment of closure manufacture *)
    (* Another option would be to make the "new" scope early & excise 'key': *)
    key      : string list; (* Not-yet-curried keys, or [] as special for "this is nullary" -- BACKWARD, first-applied key is last *)
    return : bool;    (* Should the closure execution get its own "return" continuation? *)
}

and closureExec =
    | ClosureExecUser of closureExecUser
    | ClosureExecBuiltin of (value list -> value)

and closureThis =
    | ThisBlank     (* Newly born closure *)
    | ThisNever     (* Closure is not a method and should not receive a this. *)
    | CurrentThis of value*value (* Closure is a method, has a provisional current/this. *)
    | FrozenThis of value*value  (* Closure is a method, has a final, assigned current/this. *)

(* Is this getting kind of complicated? Should curry be wrapped closures? Should callcc be separate? *)
and closureValue = {
    exec   : closureExec;
    needArgs : int;  (* Count this down as more values are added to bound *)
    bound  : value list;   (* Already-curried values -- BACKWARD, first application last *)
    this   : closureThis; (* Tracks the "current" and "this" bindings *)
}

and value =
    (* "Primitive" values *)
    | Null
    | True
    | FloatValue of float
    | StringValue of string
    | AtomValue   of string

    (* Hack types for builtins *)
    | BuiltinFunctionValue          of (value -> value) (* function argument = result *)
    | BuiltinUnaryMethodValue       of (value -> value) (* function self = result *)
    | BuiltinMethodValue   of (value -> value -> value) (* function self argument = result *)

    (* Complex user-created values *)
    | ClosureValue of closureValue
    | TableValue of tableValue
    | ObjectValue of tableValue (* Same as TableValue but treats 'this' different *)
    | ContinuationValue of executeStack * Token.codePosition

    (* Package support *)
(*  | PackageValue of value list *)
(*  | PackageDirectory of string *)

and tableBlankKind =
    | TrueBlank (* Really, actually empty. Only used for snippet scopes. *)
    | NoSet     (* Has .has. Used for immutable builtin prototypes. *)
    | NoLet     (* Has .set. Used for "flat" expression groups. *)
    | WithLet   (* Has .let. Used for scoped groups. *)
    | BoxFrom of value option (* Has .parent and uses object literal rules. *)

(* The "registers" are values 1 and 2 described in execute.ml comments *)
(* The codePositions are (1) the root of the current group (2) the symbol yielding "value 2" *)
and registerState =
    | LineStart of (value * Token.codePosition)
    | FirstValue of (value * Token.codePosition * Token.codePosition)
    | PairValue of (value * value * Token.codePosition * Token.codePosition)

(* Each frame on the stack has the two value "registers" and a codeSequence reference which
   is effectively an instruction pointer. *)
and executeFrame = {
    register : registerState;
    code : Token.codeSequence;
    scope: value;
}

(* The current state of an execution thread consists of just the stack of frames. *)
and executeStack = executeFrame list

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
let returnKeyString = "return"
let returnKey = AtomValue returnKeyString
let packageKeyString = "package"
let packageKey = AtomValue packageKeyString
let projectKeyString = "project"
let projectKey = AtomValue projectKeyString
let directoryKeyString = "directory"
let directoryKey = AtomValue directoryKeyString

let tableGet table key = CCHashtbl.get table key
let tableSet table key value = Hashtbl.replace table key value
let tableHas table key = match tableGet table key with Some _ -> true | None -> false
let tableSetString table key value = tableSet table (AtomValue key) value
let tableSetOption table key value = match value with Some x -> tableSet table key x | _ -> ()