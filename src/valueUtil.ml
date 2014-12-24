open Value

let badArg desired name var = failwith @@ "Bad argument to "^name^": Need "^desired^", got " ^ Pretty.dumpValue(var)
let badArgTable = badArg "table"
let badArgClosure = badArg "closure"
let impossibleArg name = failwith @@ "Internal failure: Impossible argument to "^name

let rawMisapplyArg a b = failwith @@ "Application failure: "^(Pretty.dumpValue a)^" can't respond to "^(Pretty.dumpValue b)

let boolCast v = if v then True else Null

let kancel _ x = x

(* let rec has some really weird restrictions. A couple functions can't be fit into the
   big and stanza below, so have to be set after the fact via reference. *)
let ternKnot                : value ref = ref Null
let rethisAssignObjectKnot  : value ref = ref Null

(* Create a closure from an ocaml function *)
let snippetClosure argCount exec =
    ClosureValue({ exec = ClosureExecBuiltin(exec); needArgs = argCount;
        bound = []; this = ThisNever; })

(* So here's a big block of stuff defining everything you need to make a new table.
   Since I really wanted that big switch on "kind", rather a lot of stuff got sucked
   into the "and" stanza. *)

(* Entry point -- give me a table of the requested type, prepopulate with basics. *)
let rec tableBlank kind : tableValue =
    let t = Hashtbl.create(1) in (match kind with
        | TrueBlank -> ()
        | NoSet -> populateWithHas t
        | NoLet -> populateWithSet t
        | WithLet ->
            populateWithSet t;
            tableSetString t "let" (makeLet kancel t)
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
    if Options.(run.trackObjects) then idGenerator := !idGenerator +. 1.0; tableSet t idKey (FloatValue !idGenerator);
    t

(* Helpers for tableBlank *)
and populateWithHas t =
    tableSetString t "has" (makeHas (TableValue t))
and populateWithSet t =
    populateWithHas t;
    tableSetString t "set" (makeSet (TableValue t))

(* Here's why it's so hard to just replace tableBlank with several functions...
   this is used all over intead of calling tableBlank directly. *)
and tableInheriting kind v =
    let t = tableBlank kind in tableSet t parentKey v;
        t

(* Making some kinds of tables requires making a blank table, because the snippets prepopulating
   the non-TrueBlank tables need scopes. *)
and snippetScope bindings =
    let scopeTable = tableBlank TrueBlank in
    List.iter (fun x -> match x with (k,v) -> tableSet scopeTable (AtomValue k) v) bindings;
    TableValue(scopeTable)

(* Define an ad hoc function using a literal string inside the interpreter. *)
and snippetTextClosure context keys text =
    ClosureValue({ exec = ClosureExecUser({code = Tokenize.snippet text; scope=snippetScope context;
        scoped = false; key = keys;
    }); needArgs = List.length keys;
        bound = []; this = ThisNever; })

(* Most tables need to be preopulated with a "has". Here's the has tester for a singular table: *)
and rawHas = snippetClosure 2 (function
    | [TableValue t;key] | [ObjectValue t;key] -> boolCast (tableHas t key)
    | [v;_] -> badArgTable "rawHas" v
    | _ -> impossibleArg "rawTern")

(* ...And a factory for a curried one that knows how to check the super class: *)
and makeHas obj = snippetTextClosure
    ["rawHas",rawHas;"tern",!ternKnot;"obj",obj;"true",Value.True;"null",Value.Null]
    ["key"]
    "tern (rawHas obj key) ^(true) ^(
         tern (rawHas obj .parent) ^(obj.parent.has key) ^(null)
     )"

(* Most tables need to be preopulated with a "set". Here's the setter for a singular table: *)
and rawSet = snippetClosure 3 (function (* TODO: Unify with makeLet? *)
    | [TableValue t as tv;key;value] | [ObjectValue t as tv;key;value] ->
        tableSet t key value;
        if Options.(run.traceSet) then print_endline @@ "Set update "^Pretty.dumpValueNewTable tv;
        Null
    | [v;_;_] -> badArgTable "rawSet" v
    | _ -> impossibleArg "rawSet")

(* ...And a factory for a curried one that knows how to check the super class: *)
and makeSet obj = snippetTextClosure
    ["rawHas",rawHas;"rawSet",rawSet;"tern",!ternKnot;"obj",obj;"true",Value.True;"null",Value.Null]
    ["key"; "value"]
    "tern (rawHas obj key) ^(rawSet obj key value) ^(
         obj.parent.set key value                # Note: Fails in an inelegant way if no parent
     )"

and makeObjectSet obj = snippetTextClosure
    ["rawHas",rawHas;"rawSet",rawSet;"tern",!ternKnot;"obj",obj;"true",Value.True;"null",Value.Null;"modifier",!rethisAssignObjectKnot]
    ["key"; "value"]
    "tern (rawHas obj key) ^(rawSet obj key (modifier value)) ^(
         obj.parent.set key (modifier value) # Note: Fails in an inelegant way if no parent
     )"

(* Many tables need to be prepopulated with a "let". Here's the let setter for a singular table: *)
and makeLet (modifier:value->value->value) (t:tableValue) = snippetClosure 2 (function
    | [key;value] ->
        tableSet t key (modifier (TableValue t) value);
        if Options.(run.traceSet) then print_endline @@ "Let update (don't trust tag) "^Pretty.dumpValueNewTable (TableValue t);
        Null
    | _ -> impossibleArg "makeLet")

(* This handles what occurs when you assign to a table while defining a new object literal.
   It takes newborn functions and assigns a this to them. (Old functions just freeze.) *)
and rawRethisAssignObjectDefinition (obj:value) v = match v with
    | ClosureValue({this=ThisBlank} as c) ->
        ClosureValue({c with this=CurrentThis(obj,obj)})
    | ClosureValue({this=CurrentThis(current,this)} as c) -> ClosureValue({c with this=FrozenThis(current,this)})
    | _ -> v

(* This handles what occurs when you assign to a table at any other time.
   The "newborn" quality that makes it possible to assign a this is lost. *)
and rawRethisAssignObject _ v = match v with
    | ClosureValue({this=ThisBlank} as c) -> ClosureValue({c with this=ThisNever})
    | ClosureValue({this=CurrentThis(current,this)} as c) -> ClosureValue({c with this=FrozenThis(current,this)})
    | _ -> v

(* We are now free of the big and stanza! *)

let rethisAssignObjectDefinition = snippetClosure 2 (function
    | [obj;a] -> rawRethisAssignObjectDefinition obj a
    | _ -> impossibleArg "rethisAssignObjectDefinition")

let rethisAssignObject = snippetClosure 1 (function
    | [a] -> rawRethisAssignObject Null a
    | _ -> impossibleArg "rethisAssignObject")

(* Tern is used by a couple snippets above. Here's the "basic" tern that does no short circuiting: *)
let rawTern = snippetClosure 3 (function
    | [Null;_;v] -> v
    | [_;v;_] -> v
    | _ -> impossibleArg "rawTern")

(* Which we then use to define tern itself: *)
let tern = snippetTextClosure
    ["rawTern", rawTern; "null", Null]
    ["pred"; "a"; "b"]
    "(rawTern pred a b) null"

let () = (* Tie some knots *)
    ternKnot := tern;
    rethisAssignObjectKnot := rethisAssignObject

let rawRethisSuperFrom obj v = match v with
    | ClosureValue({this=CurrentThis(current,_)} as c) -> ClosureValue({c with this=CurrentThis(current,obj)})
    | _ -> v

let rethisSuperFrom = snippetClosure 2 (function
    | [obj;a] -> rawRethisSuperFrom obj a
    | _ -> impossibleArg "rethisSuperFrom")

let misapplyArg = snippetClosure 2 (function
    | [a;b] -> rawMisapplyArg a b
    | _ -> impossibleArg "misapplyArg")

let makeSuper current this = snippetTextClosure
    ["rethis",rethisSuperFrom;"callCurrent",current;"obj",this;"rawHas",rawHas;"tern",tern;"misapplyArg",misapplyArg]
    ["arg"]
    "tern (rawHas callCurrent .parent) ^(rethis obj (callCurrent.parent arg)) ^(misapplyArg obj arg)"
