(* Loads a program and runs it, based on contents of Options. *)

let () =
    let processOne target =
        let buf = match target with
            | Options.File f -> Tokenize.tokenizeChannel (Token.File f) (open_in f)
            | Options.Stdin -> Tokenize.tokenizeChannel Token.Stdin stdin
            | Options.Literal s -> Tokenize.tokenizeString Token.Cmdline s
        in let location = match target with
            | Options.File f -> Loader.locationAround f
            | _ -> Loader.Cwd
        in
        (*  *)
        if Options.(run.disassemble) then print_endline (Pretty.dumpCodeTreeTerse buf) else
        if Options.(run.disassembleVerbose) then print_endline (Pretty.dumpCodeTreeDense buf) else
        ignore @@ Loader.executeProgramFrom location buf
    in
    if Options.(run.repl) then Repl.repl Options.(run.targets)
    else
        try
            List.iter processOne Options.(run.targets)
        with
            Token.CompilationError e ->
                failwith @@ Token.errorString e
