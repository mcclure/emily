open Token

let digit = [%sedlex.regexp? '0'..'9']
let number = [%sedlex.regexp? Plus digit]

let dequote s =
    let len = String.length s in String.sub s 1 (len-2)

(* TODO: REMOVE *)
let rec token_print buf =
    let token = token_print in
    let letter = [%sedlex.regexp? 'a'..'z'|'A'..'Z'] in
    match%sedlex buf with
    | '#', Star (Compl '\n') -> token buf
    | '\n'|';' -> print_endline "NEXT\n"; token buf
    | white_space -> print_endline "WHITESPACE"; token buf
    | number -> Printf.printf "Number %s\n" (Sedlexing.Latin1.lexeme buf); token buf
    | letter, Star ('A'..'Z' | 'a'..'z' | digit) -> Printf.printf "Identifier %s\n" (Sedlexing.Latin1.lexeme buf); token buf
    | '"', Star (('\\','"') | Compl '"'), '"' -> Printf.printf "String \"%s\"\n" (dequote (Sedlexing.Latin1.lexeme buf)); token buf (* TODO strip quotes*)
    | Chars "(){}[]" -> Printf.printf "Grouper %s\n" (Sedlexing.Latin1.lexeme buf); token buf
    | Plus (Chars "`~!@$%^&*-+=|':,<.>/?") -> Printf.printf "Op %s\n" (Sedlexing.Latin1.lexeme buf); token buf
    | 128 .. 255 -> print_endline "Non ASCII"
    | eof -> print_endline "EOF"
    | _ -> failwith "Unexpected character"

let rec tokenize buf (group:Token.token) : Token.token =
    let letter = [%sedlex.regexp? 'a'..'z'|'A'..'Z'] in
    let cleanup = List.rev in
    let rec proceed groupSeed lines line =
        let proceedWithLines = proceed groupSeed in
        let proceedWithLine =  proceedWithLines lines in
        let skip () = proceedWithLine line in
        let linesPlusLine () = cleanup line :: lines in
        let addToLineProceed x = proceedWithLine (x :: line) in
        let newLineProceed x = proceedWithLines (linesPlusLine()) [] in
        let closeGroup = groupSeed ( cleanup (linesPlusLine()) ) in
        match%sedlex buf with
            | '#', Star (Compl '\n') -> skip ()
            | eof -> closeGroup ()
            | white_space -> skip ()
            | number -> addToLineProceed (Number (float_of_string(Sedlexing.Utf8.lexeme buf)) )
            | _ -> failwith "Unexpected character"
    in proceed (makeToken (Some "<>") 0 Plain) [] []

let tokenize_lexbuf buf =
    tokenize buf (makeToken (Some "<>") 0 Plain [])

let tokenize_channel channel =
    let lexbuf = Sedlexing.Utf8.from_channel channel in
    tokenize_lexbuf lexbuf

let tokenize_string str =
    let lexbuf = Sedlexing.Utf8.from_string str in
    tokenize_lexbuf lexbuf
