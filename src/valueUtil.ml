open Value

let badArg desired name var = failwith @@ "Bad argument to "^name^": Need "^desired^", got " ^ Pretty.dumpValue(var)
let badArgTable = badArg "table"
let badArgClosure = badArg "closure"
let impossibleArg name = failwith @@ "Internal failure: Impossible argument to "^name

let rawMisapplyArg a b = failwith @@ "Application failure: "^(Pretty.dumpValue a)^" can't respond to "^(Pretty.dumpValue b)

let boolCast v = if v then True else Null

let ternKnot : value ref = ref Null

let snippetClosure argCount exec =
    ClosureValue({ exec = ClosureExecBuiltin(exec); needArgs = argCount;
        bound = []; this = ThisNever; })

let rec tableBlank kind : tableValue =
    let t = Hashtbl.create(1) in (match kind with
        | TrueBlank -> ()
        | NoSet -> populateWithHas t
        | NoLet -> populateWithSet t
        | WithLet -> populateWithSet t; tableSetString t "let" (makeLet t)
        | BoxFrom parent -> let box = match parent with None -> tableBlank WithLet | Some value -> tableInheriting WithLet value in
             populateWithSet t; tableSetString t "let" (makeLet box); (* TODO: Fancier *)
             tableSet t currentKey (TableValue box)
    );
    if Options.(run.trackObjects) then idGenerator := !idGenerator +. 1.0; tableSet t idKey (FloatValue !idGenerator);
    t
and populateWithHas t =
    tableSetString t "has" (makeHas (TableValue t))
and populateWithSet t =
    populateWithHas t;
    tableSetString t "set" (makeSet (TableValue t))
and tableInheriting kind v =
    let t = tableBlank kind in tableSet t parentKey v;
        t

and snippetScope bindings =
    let scopeTable = tableBlank TrueBlank in
    List.iter (fun x -> match x with (k,v) -> tableSet scopeTable (AtomValue k) v) bindings;
    TableValue(scopeTable)

and snippetTextClosure context keys text =
    ClosureValue({ exec = ClosureExecUser({code = Tokenize.snippet text; scope=snippetScope context;
        scoped = false; key = keys;
    }); needArgs = List.length keys;
        bound = []; this = ThisNever; })

and rawHas = snippetClosure 2 (function
    | [TableValue t;key] -> boolCast (tableHas t key)
    | [v;_] -> badArgTable "rawHas" v
    | _ -> impossibleArg "rawTern")
and makeHas obj = snippetTextClosure
    ["rawHas",rawHas;"tern",!ternKnot;"obj",obj;"true",Value.True;"null",Value.Null]
    ["key"]
    "tern (rawHas obj key) ^(true) ^(
         tern (rawHas obj .parent) ^(obj.parent.has key) ^(null)
     )"

and rawSet = snippetClosure 3 (function (* TODO: Unify with makeLet? *)
    | [TableValue t;key;value] -> tableSet t key value;Null
    | _ -> impossibleArg "rawSet")
and makeSet obj = snippetTextClosure
    ["rawHas",rawHas;"rawSet",rawSet;"tern",!ternKnot;"obj",obj;"true",Value.True;"null",Value.Null]
    ["key"; "value"]
    "tern (rawHas obj key) ^(rawSet obj key value) ^(
         obj.parent.set key value # Note: Fails in an inelegant way if no parent
     )"

and makeLet t = snippetClosure 2 (function
    | [key;value] -> tableSet t key value;Null
    | _ -> impossibleArg "makeLet")

let rawTern = snippetClosure 3 (function
    | [Null;_;v] -> v
    | [_;v;_] -> v
    | _ -> impossibleArg "rawTern")

let tern = snippetTextClosure
    ["rawTern", rawTern; "null", Null]
    ["pred"; "a"; "b"]
    "(rawTern pred a b) null"

let () =
    ternKnot := tern

let rawRethisAssignToObject obj v = match v with (* t1 -> t2; mark blank objects ready *)
    | ClosureValue({this=ThisBlank} as c) | ClosureValue({this=ThisReady} as c) ->
        ClosureValue({c with this=CurrentThis(obj,obj)})
    | ClosureValue({this=CurrentThis(current,this)} as c) -> ClosureValue({c with this=FrozenThis(current,this)})
    | _ -> v

let rethisAssignToObject = snippetClosure 2 (function
    | [obj;a] -> rawRethisAssignToObject obj a
    | _ -> impossibleArg "rethisAssignToObject")

let rawRethisAssignToScope _ v = match v with (* t1 -> t5; mark blank objects unthissable *)
    | ClosureValue({this=ThisBlank} as c) -> ClosureValue({c with this=ThisNever})
    | ClosureValue({this=CurrentThis(current,this)} as c) -> ClosureValue({c with this=FrozenThis(current,this)})
    | _ -> v

let rethisAssignToScope = snippetClosure 2 (function
    | [obj;a] -> rawRethisAssignToScope obj a
    | _ -> impossibleArg "rethisAssignToScope")

let rawRethisSuperFrom obj v = match v with (* t2 -> t3, t3->t4;  *)
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
    "tern (rawHas callCurrent .parent)
        ^(rethis obj (callCurrent.parent arg))
        ^(missaplyArg obj arg)
     )"
