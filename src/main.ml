let () =
	let processOne target = 
	    let a = match target with
	    	| Options.File f -> Tokenize.tokenize_channel (open_in f)
	    	| Options.Stdin -> Tokenize.tokenize_channel stdin
		in
	    (* print_endline (Token.dumpTreeDense a) *)
	    Execute.execute a
	in List.iter processOne Options.run.Options.targets
