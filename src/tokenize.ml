let digit = [%sedlex.regexp? '0'..'9']
let number = [%sedlex.regexp? Plus digit]

let dequote s =
    let len = String.length s in String.sub s 1 (len-2)

type tokenize_state = {
    mutable lineStart: int;
    mutable line: int
}

let rec tokenize name buf : Token.token = 
    let state = {lineStart=0; line=1} in
    let stateNewline () = state.lineStart <- Sedlexing.lexeme_end buf; state.line <- state.line + 1 in 
    let currentPosition () = Token.{fileName=name; lineNumber=state.line; lineOffset = Sedlexing.lexeme_end buf-state.lineStart} in
    let fileNameString n = (match n with None -> "<Input>" | Some s -> s) in
    let positionString (p : Token.codePosition) = Printf.sprintf " [%s line %d ch %d]"
        (fileNameString p.Token.fileName) p.Token.lineNumber p.Token.lineOffset in
    let currentPositionString () = positionString(currentPosition()) in
    let letterPattern = [%sedlex.regexp? 'a'..'z'|'A'..'Z'] in (* TODO: should be "alphabetic" *)
    let wordPattern = [%sedlex.regexp? letterPattern, Star ('A'..'Z' | 'a'..'z' | digit) ] in
    let floatPattern = [%sedlex.regexp? '.',number | number, Opt('.', number) ] in
    let parseFail mesg = failwith(mesg ^ currentPositionString()) in
    let cleanup = List.rev in
    let rec quotedString () = 
        let accum = Buffer.create 1 in
        let add = Buffer.add_string accum in
        let addBuf() = add (Sedlexing.Utf8.lexeme buf) in
        let rec proceed () =
            let escapedChar () = 
                match%sedlex buf with
                    | '\\' -> "\\"
                    | '"' -> "\""
                    | 'n'  -> "\n"
                    | _ -> parseFail "Unrecognized escape sequence" (* TODO: devour newlines *)
            in match%sedlex buf with
                | '\n' -> stateNewline(); addBuf(); proceed()
                | '\\' -> add (escapedChar()); proceed()
                | '"'  -> Buffer.contents accum
                | any  -> add (Sedlexing.Utf8.lexeme buf); proceed()
                | _ -> parseFail "Unrecognized escape sequence"
        in proceed()
    in let rec proceed (groupSeed : Token.token list list -> Token.token) lines line =
        let localToken = Token.makeToken (Some "<>") 0 0 in
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
                | _ -> parseFail "\".\" must be followed by an identifier"
        in let rec openGroup closure kind =
            proceed (Token.makeGroup (Some "<>") 0 0 closure kind) [] []
        in let rec openClosure closure =
            match%sedlex buf with
                | '\n' -> stateNewline (); openClosure closure
                | white_space -> openClosure closure
                | wordPattern -> openClosure (Token.ClosureWithBinding(matchedLexeme())) (* TODO: No dupes or handle dupes *)
                | '(' -> openGroup closure Token.Plain (* Sorta duplicates below *)
                | '{' -> openGroup closure Token.Scoped
                | '[' -> openGroup closure Token.Box
                | _ -> failwith @@ "Saw something unexpected after \"^\"" ^ currentPositionString()
        in let openOrdinaryGroup = openGroup Token.NonClosure
        in match%sedlex buf with
            | '#', Star (Compl '\n') -> skip ()
            | closePattern -> closeGroup () (* TODO: Check correctness of closing indicator *)
            | '"' -> addToLineProceed(localToken(Token.String(quotedString())))
            | floatPattern -> addSingle (fun x -> Token.Number(float_of_string x))
            | wordPattern -> addSingle (fun x -> Token.Word x)
            | '.' -> atom() (* TODO: Make macro *)
            | ';' -> newLineProceed()
            | '\n' -> stateNewline(); newLineProceed()
            | white_space -> skip ()
            | '(' -> addToLineProceed( openOrdinaryGroup Token.Plain )
            | '{' -> addToLineProceed( openOrdinaryGroup Token.Scoped )
            | '[' -> addToLineProceed( openOrdinaryGroup Token.Box )
            | '^' -> addToLineProceed( openClosure Token.Closure ) (* TODO: Make macro *)
            | _ -> failwith @@ "Unexpected character" ^ currentPositionString()
    in proceed (Token.makeGroup name 0 0 Token.NonClosure Token.Plain) (* TODO: eof here *) [] []

let tokenize_channel channel =
    let lexbuf = Sedlexing.Utf8.from_channel channel in
    tokenize None lexbuf

let tokenize_string str =
    let lexbuf = Sedlexing.Utf8.from_string str in
    tokenize None lexbuf
