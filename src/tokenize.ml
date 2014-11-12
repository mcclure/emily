(* This is Emily's "parser", which I'm calling a tokenizer since it doesn't do much. 
   It scans left to right, categorizing tokens, pushing on left parens and popping on right.
   The parts we'd think of a "parser" as usually doing will be handled in a second,
   currently unimplemented, macro-processing step. *)

(* Tokenize uses sedlex which is inherently stateful, so tokenize for a single source string is stateful. 
   Here's the basic state for the file parse-- basically just recording the position of the last seen newline. *)
type tokenize_state = {
    mutable lineStart: int;
    mutable line: int
}

(* Entry point to tokenize, takes a filename and a lexbuf *)
let rec tokenize name buf : Token.token = 
    (* -- Helper regexps -- *)
    let digit = [%sedlex.regexp? '0'..'9'] in
    let number = [%sedlex.regexp? Plus digit] in
    let letterPattern = [%sedlex.regexp? 'a'..'z'|'A'..'Z'] in (* TODO: should be "alphabetic" *)
    let wordPattern = [%sedlex.regexp? letterPattern, Star ('A'..'Z' | 'a'..'z' | digit) ] in
    let floatPattern = [%sedlex.regexp? '.',number | number, Opt('.', number) ] in

    (* Helper function: We treat a list as a stack by appending elements to the beginning,
       but this means we have to do a reverse operation to seal the stack at the end. *)
    let cleanup = List.rev in

    (* -- State management machinery -- *)
    (* Current tokenizer state *)
    let state = {lineStart=0; line=1} in
    (* Call when the current selected sedlex match is a newline. Mutates tokenizer state. *)
    let stateNewline () = state.lineStart <- Sedlexing.lexeme_end buf; state.line <- state.line + 1 in 
    (* Use tokenizer state to translate sedlex position into a codePosition *)
    let currentPosition () = Token.{fileName=name; lineNumber=state.line; lineOffset = Sedlexing.lexeme_end buf-state.lineStart} in
    (* Use tokenizer state to translate sedlex position into a human-readable string. *)
    let currentPositionString () = Token.positionString(currentPosition()) in
    (* Parse failure. Append human-readable code position string. *)
    let parseFail mesg = failwith(Printf.sprintf "%s %s" mesg (currentPositionString())) in
    
    (* -- Parsers -- *)

    (* Sub-parser: double-quoted strings. Call after seeing opening quote mark *)
    let rec quotedString () = 
        (* This parser works by statefully adding chars to a string buffer *)
        let accum = Buffer.create 1 in
        (* Helper function adds a literal string to the buffer *)
        let add = Buffer.add_string accum in
        (* Helper function adds a sedlex match to the buffer *)
        let addBuf() = add (Sedlexing.Utf8.lexeme buf) in
        (* Operate *)
        let rec proceed () =
            (* Call after seeing a backslash. Matches one character, returns string escape corresponds to. *)
            let escapedChar () = 
                match%sedlex buf with
                    | '\\' -> "\\"
                    | '"' -> "\""
                    | 'n'  -> "\n"
                    | _ -> parseFail "Unrecognized escape sequence" (* TODO: devour newlines *)
            (* Chew through until quoted string ends *)
            in match%sedlex buf with
                (* Treat a newline like any other char, but since sedlex doesn't track lines, we have to record it *)
                | '\n' -> stateNewline(); addBuf(); proceed()
                (* Backslash found, trigger escape handler *)
                | '\\' -> add (escapedChar()); proceed()
                (* Unescaped quote found, we are done. Return the data from the buffer. *)
                | '"'  -> Buffer.contents accum
                (* Any normal character add to the buffer and proceed. *)
                | any  -> add (Sedlexing.Utf8.lexeme buf); proceed()
                | _ -> parseFail "Unrecognized escape sequence"
        in proceed()

    in let rec proceed (groupSeed : Token.token list list -> Token.token) lines line =
        let localToken = Token.makeToken (currentPosition()) in
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
            proceed (Token.makeGroup (currentPosition()) closure kind) [] []
        in let rec openClosure closure =
            match%sedlex buf with
                | '\n' -> stateNewline (); openClosure closure
                | white_space -> openClosure closure
                | wordPattern -> openClosure (Token.ClosureWithBinding(matchedLexeme())) (* TODO: No dupes or handle dupes *)
                | '(' -> openGroup closure Token.Plain (* Sorta duplicates below *)
                | '{' -> openGroup closure Token.Scoped
                | '[' -> openGroup closure Token.Box
                | _ -> parseFail "Saw something unexpected after \"^\""
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
            | _ -> parseFail "Unexpected character"
    in proceed (Token.makeGroup (currentPosition()) Token.NonClosure Token.Plain) (* TODO: eof here *) [] []

let tokenize_channel channel =
    let lexbuf = Sedlexing.Utf8.from_channel channel in
    tokenize None lexbuf

let tokenize_string str =
    let lexbuf = Sedlexing.Utf8.from_string str in
    tokenize None lexbuf
