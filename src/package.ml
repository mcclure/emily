let nameAtom filename = Value.AtomValue (Filename.chop_extension filename)

let rec loadPackage path = if Sys.is_directory path then
        let directoryTable = ValueUtil.tableBlank Value.NoSet in
        List.iter (fun name ->
            Value.tableSet table (nameAtom name) (loadPackage (Filename.concat path name))
        ) (Sys.readdir path)
    else
        (* FIXME: Refactor, this is redundant with main *)
        let buf = Tokenize.tokenize_channel (Token.File path) (open_in path)
        in Execute.execute ~(Value.BoxFrom None) buf