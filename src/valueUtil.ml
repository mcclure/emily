(* This file contains support methods for creating values with certain properties, split out from Value for module recursion reasons. *)
open Value

(* Misc failure throw methods *)
let badArg desired name var = failwith @@ "Bad argument to "^name^": Need "^desired^", got " ^ Pretty.dumpValue(var)
let badArgTable = badArg "table"
let badArgClosure = badArg "closure"
let impossibleArg name = failwith @@ "Internal failure: Impossible argument to "^name

let rawMisapplyArg a b = failwith @@ "Application failure: "^(Pretty.dumpValue a)^" can't respond to "^(Pretty.dumpValue b)

(* Tools *)
let boolCast v = if v then True else Null
let ignoreFirst _ x = x

(* Create a closure from an ocaml function *)
let snippetClosure argCount exec =
    ClosureValue({ exec = ClosureExecBuiltin(exec); needArgs = argCount;
        bound = []; this = ThisNever; })

(* For debugging, call this after creating a hashtable set to become a Value *)
let sealTable t =
    if Options.(run.trackObjects) then idGenerator := !idGenerator +. 1.0; tableSet t idKey (FloatValue !idGenerator)

(* Same as calling tableBlank TrueBlank. We need a separate version because
   tableBlank relies on some of the functions that require tableTrueBlank
   to themselves be defined, and let rec gets awkward w/mutual recursion. *)
let tableTrueBlank () =
    let t = Hashtbl.create(1) in sealTable t; t
let tableTrueBlankInheriting v =
    let t = tableTrueBlank () in tableSet t parentKey v;
        t

(* Makes a scope to be used in a snippetTextClosure *)
let snippetScope bindings =
    let scopeTable = tableTrueBlank () in
    List.iter (fun x -> match x with (k,v) -> tableSet scopeTable (AtomValue k) v) bindings;
    TableValue(scopeTable)

(* Define an ad hoc function using a literal string inside the interpreter. *)
let snippetTextClosureAbstract source thisKind context keys text =
    ClosureValue({ exec = ClosureExecUser({code = Tokenize.snippet source text; scope=snippetScope context;
        scoped = false; key = keys;
    }); needArgs = List.length keys;
        bound = []; this = thisKind; })

(* Define an ad hoc function using a literal string inside the interpreter. *)
let snippetTextClosure source = snippetTextClosureAbstract source ThisNever
let snippetTextMethod  source = snippetTextClosureAbstract source ThisBlank

(* These first three snippet closures are relied on by the later ones *)

(* Ternary function without short-circuiting... *)
let rawTern = snippetClosure 3 (function
    | [Null;_;v] -> v
    | [_;v;_] -> v
    | _ -> impossibleArg "rawTern")

(* ...used to define the ternary function with short-circuiting: *)
let tern = snippetTextClosure (Token.Internal "tern")
    ["rawTern", rawTern; "null", Null]
    ["pred"; "a"; "b"]
    "(rawTern pred a b) null"

(* This handles what occurs when you assign to a table while defining a new object literal.
   It takes newborn functions and assigns a this to them. (Old functions just freeze.) *)
let rawRethisAssignObjectDefinition (obj:value) v = match v with
    | ClosureValue({this=ThisBlank} as c) ->
        ClosureValue({c with this=CurrentThis(obj,obj)})
    | ClosureValue({this=CurrentThis(current,this)} as c) -> ClosureValue({c with this=FrozenThis(current,this)})
    | _ -> v

(* This handles what occurs when you assign to a table at any other time.
   The "newborn" quality that makes it possible to assign a this is lost. *)
let rawRethisAssignObject _ v = match v with
    | ClosureValue({this=ThisBlank} as c) -> ClosureValue({c with this=ThisNever})
    | ClosureValue({this=CurrentThis(current,this)} as c) -> ClosureValue({c with this=FrozenThis(current,this)})
    | _ -> v

(* Emily versions of the above two *)
let rethisAssignObjectDefinition = snippetClosure 2 (function
    | [obj;a] -> rawRethisAssignObjectDefinition obj a
    | _ -> impossibleArg "rethisAssignObjectDefinition")

let rethisAssignObject = snippetClosure 1 (function
    | [a] -> rawRethisAssignObject Null a
    | _ -> impossibleArg "rethisAssignObject")

(* This next batch is the functions required to create a blank user table *)

(* Most tables need to be preopulated with a "has". Here's the has tester for a singular table: *)
let rawHas = snippetClosure 2 (function
    | [TableValue t;key] | [ObjectValue t;key] -> boolCast (tableHas t key)
    | [v;_] -> badArgTable "rawHas" v
    | _ -> impossibleArg "rawTern")

(* ...And a factory for a curried one that knows how to check the super class: *)
let makeHas obj = snippetTextClosure (Token.Internal "makeHas")
    ["rawHas",rawHas;"tern",tern;"obj",obj;"true",Value.True;"null",Value.Null]
    ["key"]
    "tern (rawHas obj key) ^(true) ^(
         tern (rawHas obj .parent) ^(obj.parent.has key) ^(null)
     )"

(* Most tables need to be preopulated with a "set". Here's the setter for a singular table: *)
let rawSet = snippetClosure 3 (function (* TODO: Unify with makeLet? *)
    | [TableValue t as tv;key;value] | [ObjectValue t as tv;key;value] ->
        tableSet t key value;
        if Options.(run.traceSet) then print_endline @@ "Set update "^Pretty.dumpValueNewTable tv;
        Null
    | [v;_;_] -> badArgTable "rawSet" v
    | _ -> impossibleArg "rawSet")

(* ...And a factory for a curried one that knows how to check the super class: *)
let makeSet obj = snippetTextClosure (Token.Internal "makeSet")
    ["rawHas",rawHas;"rawSet",rawSet;"tern",tern;"obj",obj;"true",Value.True;"null",Value.Null]
    ["key"; "value"]
    "tern (rawHas obj key) ^(rawSet obj key value) ^(
         obj.parent.set key value                # Note: Fails in an inelegant way if no parent
     )"

(* Same thing, but for an ObjectValue instead of a TableValue.
   The difference lies in how "this" is treated *)
let makeObjectSet obj = snippetTextClosure (Token.Internal "makeObjectSet")
    ["rawHas",rawHas;"rawSet",rawSet;"tern",tern;"obj",obj;"true",Value.True;"null",Value.Null;"modifier",rethisAssignObject]
    ["key"; "value"]
    "tern (rawHas obj key) ^(rawSet obj key (modifier value)) ^(
         obj.parent.set key (modifier value) # Note: Fails in an inelegant way if no parent
     )"

(* Many tables need to be prepopulated with a "let". Here's the let setter for a singular table: *)
let makeLet (modifier:value->value->value) (t:tableValue) = snippetClosure 2 (function
    | [key;value] ->
        tableSet t key (modifier (TableValue t) value);
        if Options.(run.traceSet) then print_endline @@ "Let update (don't trust tag) "^Pretty.dumpValueNewTable (TableValue t);
        Null
    | _ -> impossibleArg "makeLet")

(* Helpers for tableBlank *)
let populateWithHas t =
    tableSetString t "has" (makeHas (TableValue t))
let populateWithSet t =
    populateWithHas t;
    tableSetString t "set" (makeSet (TableValue t))

(* Give me a table of the requested type, prepopulate with basics. *)
let rec tableBlank kind : tableValue =
    let t = Hashtbl.create(1) in (match kind with
        | TrueBlank -> ()
        | NoSet -> populateWithHas t
        | NoLet -> populateWithSet t
        | WithLet ->
            populateWithSet t;
            tableSetString t "let" (makeLet ignoreFirst t)
        | BoxFrom parent ->
            (* There will be two tables made here: One a "normal" scope the object-literal assignments execute in,
               the other an "object" table that the code executed here funnel "let" values into. *)
            let box = match parent with None -> tableBlank NoSet | Some value -> tableInheriting NoSet value in
            tableSetString box "set" (makeObjectSet (ObjectValue box));
            tableSetString box "let" (makeLet rawRethisAssignObject box);
            populateWithSet t;
            tableSetString t "let" (makeLet rawRethisAssignObjectDefinition box);
            tableSet t currentKey (ObjectValue box);
            tableSet t thisKey    (ObjectValue box)
    );
    sealTable t;
    t

and tableInheriting kind v =
    let t = tableBlank kind in tableSet t parentKey v;
        t

(* Helpers for super function *)
let rawRethisSuperFrom obj v = match v with
    | ClosureValue({this=CurrentThis(current,_)} as c) -> ClosureValue({c with this=CurrentThis(current,obj)})
    | _ -> v

let rethisSuperFrom = snippetClosure 2 (function
    | [obj;a] -> rawRethisSuperFrom obj a
    | _ -> impossibleArg "rethisSuperFrom")

let misapplyArg = snippetClosure 2 (function
    | [a;b] -> rawMisapplyArg a b
    | _ -> impossibleArg "misapplyArg")

(* Factory for super functions *)
let makeSuper current this = snippetTextClosure (Token.Internal "makeSuper")
    ["rethis",rethisSuperFrom;"callCurrent",current;"obj",this;"rawHas",rawHas;"tern",tern;"misapplyArg",misapplyArg]
    ["arg"]
    "tern (rawHas callCurrent .parent) ^(rethis obj (callCurrent.parent arg)) ^(misapplyArg obj arg)"
