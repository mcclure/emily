let () =
    let a = Tokenize.tokenize_channel stdin in
    print_endline (Token.dumpTreeDense a)