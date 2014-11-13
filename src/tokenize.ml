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
(* TODO: Somehow strip blank lines? *)
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

    (* Main loop. *)
    (* Takes a constructor that's prepped with all the properties for the enclosing group, and
       needs only the final list of lines to produce a token. Returns a completed group. *)
    in let rec proceed (groupSeed : Token.codeSequence -> Token.token) lines line =
        (* Constructor for a token with the current preserved codeposition. *)
        let makeTokenHere = Token.makeToken (currentPosition()) in

        (* Right now all group closers are treated as equivalent. TODO: Don't do it like this. *)
        let closePattern = [%sedlex.regexp? '}' | ')' | ']' | eof] in

        (* Recurse with the same groupSeed we started with. *)
        let proceedWithLines = proceed groupSeed in

        (* Recurse with the same groupSeed and lines we started with. *)
        let proceedWithLine =  proceedWithLines lines in

        (* Recurse with all the same arguments  we started with. *)
        let skip () = proceedWithLine line in

        (* Helper function: Get current sedlex match *)
        let matchedLexemes () = Sedlexing.Utf8.lexeme(buf) in

        (* Complete current line & push onto current codeSequence *)
        let linesPlusLine () = cleanup line :: lines in

        (* Recurse with the groupSeed and lines we started with, & the argument pushed onto the current line *)
        let addToLineProceed x = proceedWithLine (x :: line) in

        (* Recurse with the groupSeed we started with, the current line pushed onto the codeSequence, & a new blank line *)
        let newLineProceed x = proceedWithLines (linesPlusLine()) [] in
        
        (* Complete processing the current group by completing the current codeSequence & feeding it to the groupSeed. *)
        let closeGroup () = groupSeed ( cleanup (linesPlusLine()) ) in

        (* Helper: Given a string->tokenContents mapping, make the token, add it to the line and recurse *)
        let addSingle constructor = addToLineProceed(makeTokenHere(constructor(matchedLexemes()))) in

        (* Sub-parser: Atoms. Call after seeing opening ".". TODO: allow whitespace prefix? *) 
        let rec atom() =
            match%sedlex buf with
                (* Really we're just checking for one identifier and converting it *)
                | wordPattern -> addSingle (fun x -> Token.Atom x)
                | _ -> parseFail "\".\" must be followed by an identifier"

        (* Recurse with blank code, and a new groupSeed described by the arguments *)
        in let rec openGroup closure kind =
            proceed (Token.makeGroup (currentPosition()) closure kind) [] []

        (* Variant assuming non-closure *)
        in let openOrdinaryGroup = openGroup Token.NonClosure

        (* Sub-parser: Closures. Call after seeing opening "^". *)
        in let rec openClosure closure =
            match%sedlex buf with
                (* Again: sedlex means we must track lines manually *)
                | '\n' -> stateNewline (); openClosure closure
                (* Skip white space *)
                | white_space -> openClosure closure
                (* If we see an identifier, upgrade from nullary to unary and continue *)
                | wordPattern -> (match closure with Token.Closure -> openClosure (Token.ClosureWithBinding(matchedLexemes()))
                        (* Error cases *)
                        | Token.ClosureWithBinding _ -> parseFail "Only one argument currently allowed per closure."
                        | Token.NonClosure -> parseFail "Internal consistency error: Reached impossible place"
                        )
                (* If we see a group opener, complete and re-invoke to the main parser one group level deeper *)
                | '(' -> openGroup closure Token.Plain (* Sorta duplicates below *)
                | '{' -> openGroup closure Token.Scoped
                | '[' -> openGroup closure Token.Box
                | _ -> parseFail "Saw something unexpected after \"^\""

        (* Now finally here's the actual grammar... *)
        in match%sedlex buf with
            (* Ignore comments *)
            | '#', Star (Compl '\n') -> skip ()

            (* Again: on ANY group-close symbol, we end the current group *)
            | closePattern -> closeGroup () (* TODO: Check correctness of closing indicator *)

            (* Quoted string *)
            | '"' -> addToLineProceed(makeTokenHere(Token.String(quotedString())))

            (* Floating point number *)
            | floatPattern -> addSingle (fun x -> Token.Number(float_of_string x))

            (* Local scope variable *)
            | wordPattern -> addSingle (fun x -> Token.Word x)

            (* Atom *)
            | '.' -> atom() (* TODO: Make macro *)

            (* Line demarcator *)
            | ';' -> newLineProceed()

            (* Line demarcator (but remember, we have to track newlines) *)
            | '\n' -> stateNewline(); newLineProceed()

            (* Ignore whitespace *)
            | white_space -> skip ()

            (* On groups or closures, open a new parser (NO TCO) and add its result token to the current line *)
            | '(' -> addToLineProceed( openOrdinaryGroup Token.Plain )
            | '{' -> addToLineProceed( openOrdinaryGroup Token.Scoped )
            | '[' -> addToLineProceed( openOrdinaryGroup Token.Box )
            | '^' -> addToLineProceed( openClosure Token.Closure ) (* TODO: Make macro *)
            | _ -> parseFail "Unexpected character"

    (* When first entering the parser, treat the entire program as implicitly being surrounded by parenthesis *)
    in proceed (Token.makeGroup (currentPosition()) Token.NonClosure Token.Plain) [] []

(* Tokenize entry point typed to channel *)
let tokenize_channel channel =
    let lexbuf = Sedlexing.Utf8.from_channel channel in
    tokenize None lexbuf

(* Tokenize entry point typed to string *)
let tokenize_string str =
    let lexbuf = Sedlexing.Utf8.from_string str in
    tokenize None lexbuf
