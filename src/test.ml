let digit = [%sedlex.regexp? '0'..'9']
let number = [%sedlex.regexp? Plus digit]

let rec token buf =
  let letter = [%sedlex.regexp? 'a'..'z'|'A'..'Z'] in
  match%sedlex buf with
  | '#', Star (Compl '\n') -> token buf
  | '\n'|';' -> print_endline "NEXT\n"; token buf
  | white_space -> print_endline "WHITESPACE"; token buf
  | number -> Printf.printf "Number %s\n" (Sedlexing.Latin1.lexeme buf); token buf
  | letter, Star ('A'..'Z' | 'a'..'z' | digit) -> Printf.printf "Identifier %s\n" (Sedlexing.Latin1.lexeme buf); token buf
  | '"', Star (Compl '"'), '"' -> Printf.printf "String %s\n" (Sedlexing.Latin1.lexeme buf); token buf (* TODO strip quotes*)
  | Chars "(){}[]" -> Printf.printf "Grouper %s\n" (Sedlexing.Latin1.lexeme buf); token buf
  | Plus (Chars "`~!@$%^&*-+=|':,<.>/?") -> Printf.printf "Op %s\n" (Sedlexing.Latin1.lexeme buf); token buf
  | 128 .. 255 -> print_endline "Non ASCII"
  | eof -> print_endline "EOF"
  | _ -> failwith "Unexpected character"

let () =
  let lexbuf = Sedlexing.Latin1.from_stream (Stream.of_channel stdin) in
  token lexbuf
