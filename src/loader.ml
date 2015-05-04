(* Set up environment and invoke Execute *)

(* File handling utilities *)

(* Convert a filename to an atom key for a loader *)
(* FIXME: Refuse to process "unspeakable" atoms, like "file*name"? *)
let nameAtom filename = Value.AtomValue (try
        Filename.chop_extension filename      (* If there is an extension remove it *)
    with
        Invalid_argument _ -> filename)       (* If there is no extension do nothing *)

(* TODO: This should be normalized. Strongly consider using extunix.realpath instead *)
let readlink path = FileUtil.readlink path
let bootPath = readlink @@ Sys.getcwd()
let packageRootPath = [%getenv "BUILD_PACKAGE_DIR"]

(* What should the target of this particular loader be? *)
type loaderSource =
    | NoSource                  (* I don't want the loader *)
    | SelfSource                (* I want the loader inferred from context *)
    | Source of Value.value     (* I want it to load from a specific path *)

(* From what source should the project/directory loaders for this execution come? *)
type loadLocation =
    | Cwd             (* From the current working directory *)
    | Path of string  (* From a known location *)

(* Given a loaderSource and a known context path, eliminate the SelfSource case *)
let selfFilter self source = match source with SelfSource -> Source self | _ -> source

(* Given a pre-selfFiltered loaderSource, convert to an option. *)
(* FIXME: Should the error state (SelfSource) instead be an allowed case? *)
let knownFilter source = match source with
    | NoSource -> None
    | Source x -> Some x
    | _ -> failwith "Internal error: Package loader attempted to load a file as if it were a directory"

(* There is one "base" starter plus one substarter for each file executed.
   The base starter lacks a project/directory, the others have it. *)

(* Given a starter, make a new starter with a unique scope that is the child of the old starter's scope.
   Return both the starter and the new scope. *)
(* THIS COMMENT IS WRONG, FIX IT *)
let subStarterWith starter table =
    {starter with Value.rootScope=Value.TableValue table}
let subStarterPair starter =
    let table = ValueUtil.tableInheriting Value.NoLet starter.Value.rootScope in
    table,subStarterWith starter @@ ValueUtil.tableInheriting Value.NoLet starter.Value.rootScope

(* Given a starter, make a new starter with a subscope and the requested project/directory. *)
let starterForExecute starter (project:Value.value option) (directory:Value.value option) =
    let table,subStarter = subStarterPair starter in
    let prepareScope = Value.tableSetOption table in
    prepareScope Value.projectKey   project;
    prepareScope Value.directoryKey directory; (* FIXME: Shouldn't directory=None be a failure? *)
    subStarter

(* Loader is invoking execute internally to load a package from a file. *)
let executePackage starter (project:Value.value option) (directory:Value.value option) buf =
    Execute.execute (starterForExecute starter project directory) buf

(* Create a package loader object. Will recursively call itself in a lazy way on field access.
   Directory and projectSource will be replaced as needed on field access, will not. *)
(* TODO: Consider a guard on multi-loading? *)
(* TODO: Here "lazy" means if you access a field corresponding to a file, the file is loaded.
         Maybe loading should be even lazier, such that load when a field is loaded *from* a file, load occurs?
         This would make prototype loading way easier. *)
let loadPackageFile starter (projectSource:loaderSource) (directory:loaderSource) path =
    (* FIXME: What if knownFilter is NoSource here? This is the "file where expected a directory" case. *)
    let buf = Tokenize.tokenizeChannel ~kind:(Token.Box Token.NewScope) (Token.File path) (open_in path)
    in executePackage starter (knownFilter projectSource) (knownFilter directory) buf
let rec loadPackage starter (projectSource:loaderSource) (directory:loaderSource) path =
    try
        (* COMMENT ME!!! This is not good enough. *)
        if String.length path == 0 then
            raise @@ Sys_error "Empty path"
        else if Sys.is_directory path then
            let directoryTable = ValueUtil.tableBlank Value.NoSet in
            let directoryObject = Value.ObjectValue directoryTable in
            let directoryFilter = selfFilter directoryObject in
            let proceed = loadPackage starter (directoryFilter projectSource) (Source directoryObject) in
            Array.iter (fun name ->
                ValueUtil.tableSetLazy directoryTable (nameAtom name)
                    (fun _ -> proceed (Filename.concat path name))
            ) (Sys.readdir path); directoryObject
        else
            loadPackageFile starter projectSource directory path
    with Sys_error s ->
        Value.TableValue( ValueUtil.tableBlank Value.NoSet )

(* This is the "load project" step. It should probably be averted. *)
(* FIXME: This is old style *)
let projectForLocation starter defaultLocation =
    let projectPath = match Options.(run.projectPath) with
        | Some s -> s
        | _ -> (match defaultLocation with Cwd -> bootPath | Path str -> str) in
    loadPackage starter SelfSource NoSource projectPath

(* For external use: Given a file, get the loadLocation it would be executed within. *)
let locationAround path =
    Path (Filename.dirname path)

(* External entry point: Build a starter *)
let completeStarter withProjectLocation =
    let rootScope = ValueUtil.tableTrueBlank() in
    let nv() = Value.TableValue(ValueUtil.tableTrueBlank()) in (* "New value" *)
    let packageStarter = Value.{rootScope=Value.TableValue rootScope;context={
        nullProto=nv(); trueProto=nv(); floatProto=nv();
        stringProto=nv(); atomProto=nv(); objectProto=nv()}} in
    let package = loadPackage packageStarter NoSource NoSource @@
        match Options.(run.packagePath) with Some s -> s | _ -> packageRootPath
    in
    let populateProto proto pathKey =
        (* TODO convert path to either path or value to load from  *)
        (* TODO find some way to make this not assume path loaded from disk *)
        (* FIXME plus emily/prototype in there *)
        let path = FilePath.concat packageRootPath (pathKey ^ ".em") in
        ignore @@ loadPackageFile
            (subStarterWith packageStarter @@
                ValueUtil.boxBlank (ValueUtil.InheritValue proto) packageStarter.Value.rootScope)
            NoSource NoSource path
    in
    (* FIXME: Set internal here *)
    Value.tableSet rootScope Value.packageKey package;
    populateProto Value.(packageStarter.rootScope)           "scope";
    populateProto Value.(packageStarter.context.nullProto)   "null";
    populateProto Value.(packageStarter.context.trueProto)   "true";
    populateProto Value.(packageStarter.context.floatProto)  "float";
    populateProto Value.(packageStarter.context.stringProto) "string";
    populateProto Value.(packageStarter.context.atomProto)   "atom";
    populateProto Value.(packageStarter.context.objectProto) "object";
    let project = projectForLocation packageStarter withProjectLocation in
    let scope,starter = subStarterPair packageStarter in
    Value.tableSet scope Value.projectKey   project;
    Value.tableSet scope Value.directoryKey project;
    starter

(* External entry point: Given a starter and a buffer, execute it *)
let executeProgramFrom location buf =
    Execute.execute (completeStarter location) buf
