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

let rec tokenize buf : Token.token =
    let letterPattern = [%sedlex.regexp? 'a'..'z'|'A'..'Z'] in
    let wordPattern = [%sedlex.regexp? letterPattern, Star ('A'..'Z' | 'a'..'z' | digit) ] in
    let floatPattern = [%sedlex.regexp? '.',number | number, Opt('.', number) ] in
    let cleanup = List.rev in
    let rec quotedString () = 
        let accum = Buffer.create 1 in
        let add = Buffer.add_string accum in
        let rec proceed () =
            let escapedChar () = 
                match%sedlex buf with
                    | '\\' -> "\\"
                    | '"' -> "\""
                    | 'n'  -> "\n"
                    | _ -> failwith "Unrecognized escape sequence" (* TODO: devour newlines *)
            in match%sedlex buf with
                | '\\' -> add (escapedChar()); proceed()
                | '"'  -> Buffer.contents accum
                | any  -> add (Sedlexing.Utf8.lexeme buf); proceed()
                | _ -> failwith "This error is literally impossible"
        in proceed()
    in let rec proceed (groupSeed : Token.token list list -> Token.token) lines line =
        let localToken = Token.makeToken (Some "<>") 0 in
        let closePattern = [%sedlex.regexp? '}' | ')' | ']' | eof] in
        let proceedWithLines = proceed groupSeed in
        let proceedWithLine =  proceedWithLines lines in
        let skip () = proceedWithLine line in
        let matchedLexeme () = Sedlexing.Utf8.lexeme(buf) in
        let linesPlusLine () = cleanup line :: lines in
        let addToLineProceed x = proceedWithLine (x :: line) in
        let newLineProceed x = proceedWithLines (linesPlusLine()) [] in
        let closeGroup () = groupSeed ( cleanup (linesPlusLine()) ) in
        let addSingle constructor = addToLineProceed(localToken(constructor(matchedLexeme()))) in
        let rec atom() =
            match%sedlex buf with
                | wordPattern -> addSingle (fun x -> Token.Atom x)
                | _ -> failwith "\".\" must be followed by an identifier"
        in let rec openGroup kind =
            let closeString = match kind with
                | Token.Plain -> ')'
                | Token.Scoped | Token.Box | Token.Closure | Token.ClosureWithBinding _ -> '}'
                | Token.Box -> ']' (* TODO: Do something with this? *)
            in proceed (Token.makeGroup (Some "<>") 0 kind) [] []
        in let rec openClosure kind =
            match%sedlex buf with
                | white_space -> openClosure kind
                | wordPattern -> openClosure (Token.ClosureWithBinding(matchedLexeme())) (* TODO: No dupes or handle dupes *)
                | '{' -> openGroup kind
                | _ -> failwith "Saw something unexpected after \"^\""
        in match%sedlex buf with
            | '#', Star (Compl '\n') -> skip ()
            | closePattern -> closeGroup ()
            | '"' -> addToLineProceed(localToken(Token.String(quotedString())))
            | floatPattern -> addSingle (fun x -> Token.Number(float_of_string x))
            | wordPattern -> addSingle (fun x -> Token.Word x)
            | '.' -> atom() (* TODO: Make macro *)
            | ';' | '\n' -> newLineProceed()
            | white_space -> skip ()
            | '(' -> openGroup Token.Plain
            | '^' -> openClosure Token.Closure (* TODO: Make macro *)
            | _ -> failwith "Unexpected character"
    in proceed (Token.makeGroup (Some "<>") 0 Token.Plain) (* TODO: eof here *) [] []

let tokenize_channel channel =
    let lexbuf = Sedlexing.Utf8.from_channel channel in
    tokenize lexbuf

let tokenize_string str =
    let lexbuf = Sedlexing.Utf8.from_string str in
    tokenize lexbuf
