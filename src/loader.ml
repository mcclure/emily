let nameAtom filename = Value.AtomValue (Filename.chop_extension filename)

(* TODO: This should be normalized. Strongly consider using extunix.realpath instead *)
let readlink path = FileUtil.readlink path
let bootPath = readlink @@ Sys.getcwd()
let exePath  = readlink @@
    Filename.concat (Sys.getcwd()) (Filename.dirname @@ Array.get Sys.argv 0)
let () = print_endline bootPath; print_endline exePath

let basicScope () =
    Execute.scopeInheriting Value.WithLet BuiltinScope.scopePrototype

let executeBasic buf =
    Execute.execute (basicScope()) buf

let rec loadPackage path = if Sys.is_directory path then
        let directoryTable = ValueUtil.tableBlank Value.NoSet in
        Array.iter (fun name ->
            Value.tableSet directoryTable (nameAtom name) (loadPackage (Filename.concat path name))
        ) (Sys.readdir path); Value.ObjectValue directoryTable
    else
        (* FIXME: Refactor, this is redundant with main *)
        let buf = Tokenize.tokenize_channel (Token.File path) (open_in path)
        in executeBasic buf; Value.Null (* FIXME: Get return *)

(* let package =  *)

let executeProgram = executeBasic
