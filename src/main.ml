(* Loads a program and runs it, based on contents of Options. *)

let () =
    let processOne target =
        let obuf = match target with
            | Options.File f -> Some(Tokenize.tokenize_channel (Token.File f) (open_in f))
            | Options.Stdin -> Some(Tokenize.tokenize_channel Token.Stdin stdin)
            | Options.Literal s -> Some(Tokenize.tokenize_string Token.Cmdline s)
            | Options.Repl -> None
        in
        (*  *)
        match obuf with
          | Some(buf) ->
             if Options.(run.disassemble) then print_endline (Pretty.dumpCodeTreeTerse buf) else
             if Options.(run.disassembleVerbose) then print_endline (Pretty.dumpCodeTreeDense buf) else 
             Execute.execute buf
          | None ->
             Execute.repl
    in List.iter processOne Options.(run.targets)
