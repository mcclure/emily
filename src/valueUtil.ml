open Value

let badArg desired name var = failwith @@ "Bad argument to "^name^": Need "^desired^", got " ^ Pretty.dumpValue(var)
let badArgTable = badArg "table"
let badArgClosure = badArg "closure"
let impossibleArg name = failwith @@ "Internal failure: Impossible argument to "^name

let boolCast v = if v then True else Null

let ternKnot : value ref = ref Null

let rec tableBlank kind : tableValue =
    let t = Hashtbl.create(1) in (match kind with
        | TrueBlank -> ()
        | NoLet -> populateUserTable t
        | WithLet -> populateUserTable t; tableSetString t "let" (TableLetValue t)
        | BoxFrom parent -> let box = match parent with None -> tableBlank WithLet | Some value -> tableInheriting WithLet value in
             tableSetString t "set" (TableSetValue t); tableSetString t "let" (TableLetValue box); (* TODO: Fancier *)
             tableSet t currentKey (TableValue box)
    );
    if Options.(run.trackObjects) then idGenerator := !idGenerator +. 1.0; tableSet t idKey (FloatValue !idGenerator);
    t
and populateUserTable t =
    tableSetString t "set" (TableSetValue t);
    tableSetString t "has" (makeHas (TableValue t))
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
        needThis = false; bound = []; this = Blank; })

and rawHas = snippetClosure 2 (function
    | [TableValue t;key] -> boolCast (tableHas t key)
    | [v;_] -> badArgTable "rawHas" v
    | _ -> impossibleArg "rawTern")
and makeHas obj = snippetTextClosure
    ["rawHas",rawHas;"tern",!ternKnot;"obj",obj]
    ["key"]
    "tern (rawHas obj key) ^(true) ^(
         tern (rawHas obj .parent) ^(obj.parent.has key) ^(null)
     )"

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
