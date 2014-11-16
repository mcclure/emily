(* Loads a program and runs it, based on contents of Options. *)

let () =
	let processOne target = 
	    let buf = match target with
	    	| Options.File f -> Tokenize.tokenize_channel (open_in f)
	    	| Options.Stdin -> Tokenize.tokenize_channel stdin
	    	| Options.Literal s -> Tokenize.tokenize_string s
		in
	    (*  *)
	    if Options.(run.disassemble) then print_endline (Pretty.dumpTreeTerse buf) else
	    if Options.(run.disassembleVerbose) then print_endline (Pretty.dumpTreeDense buf) else
	    Execute.execute buf
	in List.iter processOne Options.(run.targets)
