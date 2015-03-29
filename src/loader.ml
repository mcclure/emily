let nameAtom filename = Value.AtomValue (try
        Filename.chop_extension filename
    with
        Invalid_argument _ -> filename)

(* TODO: This should be normalized. Strongly consider using extunix.realpath instead *)
let readlink path = FileUtil.readlink path
let bootPath = readlink @@ Sys.getcwd()
let exePath  = readlink @@
    Filename.concat (Sys.getcwd()) (Filename.dirname @@ Array.get Sys.argv 0)
let packageRootPath = List.fold_left Filename.concat exePath [".."; "lib"; "emily"; Options.version]

type loaderSource =
    | NoSource
    | SelfSource
    | Source of Value.value

type loadLocation =
    | Cwd
    | Path of string

let selfFilter self source = match source with SelfSource -> Source self | _ -> source

(* FIXME: Should the error state be allowed? *)
let knownFilter source = match source with
    | NoSource -> None
    | Source x -> Some x
    | _ -> failwith "Internal error: Package loader attempted to load a file as if it were a directory"

let tableWithLoaders packageRoot project directory =
    let scope = ValueUtil.tableInheriting Value.WithLet BuiltinScope.scopePrototype in
    let prepareScope = Value.tableSetOption scope in
    prepareScope Value.packageKey   packageRoot;
    prepareScope Value.projectKey   project;
    prepareScope Value.directoryKey directory;
    scope

let scopeForExecute packageRoot project directory =
    let scope = tableWithLoaders packageRoot project directory in
    Value.TableValue scope

let executePackage packageRoot project directory buf =
    let scope = scopeForExecute packageRoot project directory in
    Execute.execute scope buf

let rec loadPackage packageSource projectSource directory path =
    if Sys.is_directory path then
        let directoryTable = ValueUtil.tableBlank Value.NoSet in
        let directoryObject = Value.ObjectValue directoryTable in
        let directoryFilter = selfFilter directoryObject in
        let proceed = loadPackage (directoryFilter packageSource) (directoryFilter projectSource) (Some directoryObject) in
        Array.iter (fun name ->
            ValueUtil.tableSetLazy directoryTable (nameAtom name)
                (fun _ -> proceed (Filename.concat path name))
        ) (Sys.readdir path); directoryObject
    else
        let buf = Tokenize.tokenizeChannel ~kind:(Token.Box Token.NewScope) (Token.File path) (open_in path)
        in executePackage (knownFilter packageSource) (knownFilter projectSource) directory buf

let packageRepo = loadPackage SelfSource NoSource None
    (match Options.(run.packagePath) with Some s -> s | _ -> packageRootPath)

(* This leaks Private, we need to execute the package as a box *)
let executeProgram project buf =
    let scope = scopeForExecute (Some packageRepo) project project in
    Execute.execute scope buf

let loadLocation defaultLocation =
    let projectPath = match Options.(run.packagePath) with
        | Some s -> s
        | _ -> (match defaultLocation with Cwd -> bootPath | Path str -> str) in
    loadPackage (Source packageRepo) SelfSource None projectPath

let locationAround path =
    Path (Filename.dirname path)

let executeProgramFrom location buf =
    let project = loadLocation location in
    let scope = scopeForExecute (Some packageRepo) (Some project) (Some project) in
    Execute.execute scope buf
