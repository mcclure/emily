let nameAtom filename = Value.AtomValue (try
        Filename.chop_extension filename
    with
        Invalid_argument _ -> filename)

(* TODO: This should be normalized. Strongly consider using extunix.realpath instead *)
let readlink path = FileUtil.readlink path
let bootPath = readlink @@ Sys.getcwd()
let exePath  = readlink @@
    Filename.concat (Sys.getcwd()) (Filename.dirname @@ Array.get Sys.argv 0)

let basicScope kind =
    Execute.scopeInheriting Value.WithLet BuiltinScope.scopePrototype

let executePackage buf =
    let scope = basicScope () in
    ignore @@ Execute.execute scope buf;
    scope

let rec loadPackage path = if Sys.is_directory path then
        let directoryTable = ValueUtil.tableBlank Value.NoSet in
        Array.iter (fun name ->
            ValueUtil.tableSetLazy directoryTable (nameAtom name)
                (fun _ -> loadPackage (Filename.concat path name))
        ) (Sys.readdir path); Value.ObjectValue directoryTable
    else
        let buf = Tokenize.tokenize_channel (Token.File path) (open_in path)
        in executePackage buf

let packageRepo = loadPackage @@ List.fold_left Filename.concat exePath [".."; "lib"; "emily"; Options.version]

let executeProgram buf =
    let scope = basicScope () in
    (match scope with Value.TableValue table | Value.ObjectValue table ->
        Value.tableSet table Value.packageKey packageRepo
        | _ -> Execute.internalFail() );
    Execute.execute scope buf
