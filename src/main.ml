open Tokenize

let () =
    let a = tokenize_channel stdin in
    print_endline (Token.dumpTree a)