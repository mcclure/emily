(* Macro processing *)

(* Last thing we always do is make sure no symbols survive after macro processing. *)
let verifySymbols l =
    List.iter (function
        | {Token.contents=Token.Symbol s;Token.at=at} -> failwith @@ "Unrecognized symbol "^ s ^" at " ^ Token.positionString at
        | _ -> ()
    ) l;
    l

(* Types for macro processing. *)
type macroPriority = L of float | R of float (* See builtinMacros comment *)
type singleLine = Token.token list

(* Note what a single macro does:
    The macro processor sweeps over a line, keeping a persistent state consisting of
    "past" (tokens behind cursor, reverse order) "present" (token at cursor) and
    "future" (tokens ahead of cursor). A macro replaces all 3 with a new line. *)
type macroFunction = singleLine -> Token.token -> singleLine -> singleLine
type macroSpec  = { priority : macroPriority ; specFunction : macroFunction }
type macroMatch = {
    matchFunction: macroFunction ;
    past : singleLine; present : Token.token; future : singleLine
}

(* The set of loaded macros lives here. *)
let macroTable = Hashtbl.create(1)

(* TODO: This is awful, macros should be saving the positions they're derived from. *)
let standardGroup = Token.makeGroup Token.noPosition Token.NonClosure Token.Plain
(* Note: standardClosure makes no-return closures *)
let standardClosure = Token.makeGroup Token.noPosition (Token.ClosureWithBinding (false,[])) Token.Plain
let standardToken = Token.makeToken Token.noPosition

(* Macro processing, based on whatever builtinMacros contains *)
let rec process l =
    if Options.(run.stepMacro) then print_endline @@ Pretty.dumpCodeTreeTerse @@ standardGroup [l];

    (* Search for macro to process next. Priority None/line None means none known yet. *)
    let rec findIdeal (bestPriority:macroPriority option) bestLine (past:singleLine) present future : macroMatch option =
        (* Iterate cursor *)
        let proceed priority line =
            match future with
                (* Future is empty, so future has iterated to end of line *)
                | [] -> line

                (* Future is nonempty, so move the cursor forward. *)
                | nextToken :: nextFuture -> findIdeal priority line (present::past) nextToken nextFuture

        (* Iterate cursor leaving priority and line unchanged *)
        in let skip() =
            proceed bestPriority bestLine

        (* Investigate token under cursor *)
        in match present.Token.contents with
            (* Words or symbols can currently be triggers for macros. *)
            | Token.Word s | Token.Symbol s ->
                (* Is the current word/symbol a thing in the macro table? *)
                let v = CCHashtbl.get macroTable s in
                (match v with
                    (* It's in the table; now to decide if it's an ideal match. *)
                    | Some {priority;specFunction} ->
                        (* True if this macro is better fit than the current candidate. *)
                        let better = (match bestPriority,priority with
                            (* No matches yet, automatic win. *)
                            | None,_ -> true

                            (* If associativity varies, we can determine winner based on that alone: *)
                            (* Prefer higher priority, but break ties toward left-first macros over right-first ones. *)
                            | Some L(left),R(right) -> left < right
                            | Some R(left),L(right) -> left <= right

                            (* "Process leftmost first": Prefer higher priority, break ties to the left. *)
                            | Some L(left),L(right) -> left < right

                            (* "Process rightmost first": Prefer higher priority, break ties to the right. *)
                            | Some R(left),R(right) -> left <= right
                        ) in
                        if better then
                            proceed (Some priority) (Some {past; present; future; matchFunction=specFunction})

                        (* It's a worse match than the current best guess. *)
                        else skip()
                    (* It's not in the table. *)
                    | _ -> skip() )
            (* It's not even a candidate to trigger a macro. *)
            | _ -> skip()

    (* Actually process macro *)
    in match l with
        (* Special case: Line is empty, do nothing. *)
        | [] -> l

        (* Split out first item to use as the findideal "present" cursor. *)
        | present::future ->
            (* Repeatedly run findIdeal until there are no more macros in the line. *)
            (match findIdeal None None [] present future with
                (* No macros triggered! Sanitize the line and return it. *)
                | None -> verifySymbols l

                (* A macro was found. Run the macro, then re-process the adjusted line. *)
                | Some {matchFunction; past; present; future} ->
                    if Options.(run.stepMacro) then print_endline @@ "    ...becomes:";
                    process (matchFunction past present future) )

(* The macros themselves *)

(* Support functions for macros *)

let newFuture f = standardGroup [process f] (* Insert a forward-time group *)
let newPast p   = newFuture (List.rev p)    (* Insert a reverse-time group *)
let newFutureClosure f = standardClosure [process f] (* Insert a forward-time group *)

(* A recurring pattern in the current macros is to insert a new single token
   into "the middle" of an established past and future *)
let arrangeToken past present future =
    [ newFuture @@ List.concat [List.rev past; [present]; future] ]
let arrange past present future =
    arrangeToken past (newFuture present) future

(* Constructors that return working macros *)

(* Given argument "op", make a macro to turn `a b … OP d e …` into `(a b …) .op (d e …)` *)
let makeSplitter atomString : macroFunction = (fun past _ future ->
    [ newPast past ; standardToken @@ Token.Atom atomString ; newFuture future]
)

(* Given argument "op", make a macro to turn `OP a` into `((a) .op)` *)
let makeUnary atomString : macroFunction = (fun past present future ->
    match future with
        | a :: farFuture ->
            arrange past [a; standardToken @@ Token.Atom atomString] farFuture
        | _ -> failwith @@ (Pretty.dumpCodeTreeTerse present) ^ " must be followed by a symbol"
)

(* Given argument "op", make a macro to turn `OP a` into `(op (a))` *)
let makePrefixUnary wordString : macroFunction = (fun past present future ->
    match future with
        | a :: farFuture ->
            arrange past [standardToken @@ Token.Word wordString; a] farFuture
        | _ -> failwith @@ (Pretty.dumpCodeTreeTerse present) ^ " must be followed by a symbol"
)

(* Given argument "op", make a macro to turn `a b … OP d e …` into `(op (a b …) (d e …)` *)
(* Unused. TODO: Use this for a future "and" in the global namespace? *)
let makeSplitterPrefix wordString : macroFunction = (fun past _ future ->
    [ standardToken @@ Token.Word wordString ; newPast past ; newFuture future ]
)

let makeSplitterInvert atomString : macroFunction = (fun past _ future ->
    [ standardToken @@ Token.Word "not" ; newFuture
        [ newPast past ; standardToken @@ Token.Atom atomString ; newFuture future]
    ]
)

(* One-off macros *)

(* Ridiculous thing that only for testing the macro system itself. *)
(* Prints what's happening, then deletes itself. *)
let debugOp (past:singleLine) (present:Token.token) (future:singleLine) =
    print_endline @@ "Debug macro:";
    print_endline @@ "\tPast:    " ^ (Pretty.dumpCodeTreeTerse @@ standardGroup @@ [List.rev past]);
    print_endline @@ "\tPresent: " ^ (Pretty.dumpCodeTreeTerse @@ present);
    print_endline @@ "\tFuture:  " ^ (Pretty.dumpCodeTreeTerse @@ standardGroup @@ [future]);
    List.concat [List.rev past; future]

(* Apply operator-- Works like ocaml @@ or haskell $ *)
let applyRight past _ future =
    [ newPast @@ newFuture future :: past ]

(* "Apply pair"; works like unlambda backtick *)
let backtick past _ future =
    match future with
        | a :: b :: farFuture ->
            arrange past [a;b] farFuture
        | _ -> failwith "` must be followed by two symbols"

(* Works like ocaml @@ or haskell $ *)
let rec question past _ future =
    let result cond a b =
        [standardToken @@ Token.Word "tern";
            newFuture cond; newFutureClosure a; newFutureClosure b]
    in let rec scan a rest =
        match rest with
            | {Token.contents=Token.Symbol ":"}::moreRest ->
                result (List.rev past) (List.rev a) moreRest
            | {Token.contents=Token.Symbol "?"}::moreRest ->
                failwith "Nesting like ? ? : : is not allowed."
            | token::moreRest ->
                scan (token::a) moreRest
            | [] -> failwith ": expected somewhere to right of ?"
    in scan [] future

(* Assignment operator-- semantics are relatively complex. TODO: Docs. *)
let assignment past _ future =
    (* The final parsed assignment will consist of a list of normal assignments
       and a list of ^ variables for a function. Perform that assignment here: *)
    let result lookups bindings =
        (* The token to be eventually assigned is easy to compute early, so do that. *)
        let rightside = match bindings with
            (* No bindings; this is a normal assignment. *)
            | None -> newFuture future

            (* Bindings exist: This is a function definition. *)
            | Some bindings  -> Token.makeGroup Token.noPosition (Token.ClosureWithBinding (true,(List.rev bindings)))
                    Token.Plain [process future]

        (* Recurse to try again with a different command. *)
        (* TODO: This is all wrong... set should be default, let should be the extension.
           However this will require... something to allow [] to work right. *)
        in let rec resultForCommand lookups cmd =

            (* Done with bindings now, just have to figure out what we're assigning to *)
            match (List.rev lookups),cmd with
                (* ...Nothing? *)
                | [],_ -> failwith "Found a =, but nothing to assign to."

                (* Sorta awkward, detect the "nonlocal" prefix and swap out let. This should be generalized. *)
                | {Token.contents=Token.Word "nonlocal"}::moreLookups,"let" -> resultForCommand moreLookups "set"

                (* Looks like a = b *)
                | [{Token.contents=Token.Word name}],_ -> [standardToken @@ Token.Word cmd; standardToken @@ Token.Atom name; rightside]

                (* Looks like a b ... = c *)
                | ({Token.contents=Token.Word name} as firstToken)::moreLookups,_ ->
                    (match (List.rev moreLookups) with
                        (* Note what's happening here: We're slicing off the FINAL element, first in the reversed list. *)
                        | finalToken::middleLookups ->
                            List.concat [[firstToken]; List.rev middleLookups; [standardToken @@ Token.Atom cmd; finalToken; rightside]]

                        (* Excluded by [{Token.word}] case above *)
                        | _ -> failwith "Internal failure: Reached impossible place" )

                (* Apparently did something like a.b.c.d = *)
                | _,_ -> failwith "= operator can't handle more than two left-side tokens yet."

        in resultForCommand lookups "let"

    (* Parsing loop, build the lookups and bindings list *)
    in let rec processLeft remainingLeft lookups bindings =
        match remainingLeft,bindings with
            (* If we see a ^, switch to loading bindings *)
            | {Token.contents=Token.Symbol "^"}::moreLeft,None ->
                processLeft moreLeft lookups (Some [])

            (* If we're already loading bindings, just skip it *)
            | {Token.contents=Token.Symbol "^"}::moreLeft,_ ->
                processLeft moreLeft lookups bindings

            (* Sanitize any symbols that aren't cleared for the left side of an = *)
            | {Token.contents=Token.Symbol x} :: _,_ -> failwith @@ "Unexpected symbol "^x^" to left of ="

            (* We're adding bindings *)
            | {Token.contents=Token.Word b} :: restPast,Some bindings ->
                processLeft restPast lookups (Some (b::bindings))

            (* We're adding lookups *)
            | l :: restPast,None ->
                processLeft restPast (l::lookups) None

            (* There is no more past, Jump to result. *)
            | [],_ -> result lookups bindings

            (* Probably a value to the right of ^ *)
            | _ -> failwith "Found something unexpected to the left of a ="

    in processLeft (List.rev past) [] None

let closureConstruct withReturn =
    fun past present future ->
        let rec openClosure bindings future =
            match future with
                | {Token.contents=Token.Symbol "^"} :: moreFuture ->
                    openClosure bindings moreFuture
                | {Token.contents=Token.Word b} :: moreFuture ->
                    openClosure (b::bindings) moreFuture
                | {Token.contents=Token.Group {Token.closure=Token.NonClosure;Token.kind;Token.items}} :: moreFuture ->
                    arrangeToken past (Token.makeGroup Token.noPosition (Token.ClosureWithBinding(withReturn,(List.rev bindings))) kind items) moreFuture
                | [] -> failwith @@ "Body missing for closure"
                | _ ->  failwith @@ "Unexpected symbol after ^"

        in openClosure [] future

let atom past present future =
    match future with
        | {Token.contents=Token.Word a} :: moreFuture ->
            arrangeToken past (standardToken @@ Token.Atom a) moreFuture
        | _ -> failwith "Expected identifier after ."

(* Just to be as explicit as possible:

   Each macro has a priority number and a direction preference.
   If the priority number is high, the macro is high priority and it gets interpreted first.
   If sweep direction is L, macros are evaluated "leftmost first"  (moving left to right)
   If sweep direction is R, macros are evaluated "rightmost first" (moving right to left)
   If there are multiple macros of the same priority, all the L macros (prefer-left)
   are interpreted first, and all of the R macros (prefer-right) after.
   (I recommend against mixing L and R macros on a single priority.)

   Notice how priority and sweep direction differ from "precedence" and "associativity".
   They're essentially opposites. The later a splitter macro evaluates, the higher
   "precedence" the associated operator will appear to have, because splitter macros
   wrap parenthesis around *everything else*, not around themselves.
   For similar reasons, right-preference likes like left-associativity and vice versa.

   So this table goes:
    - From lowest priority to highest priority.
    - From lowest-magnitude priority number to highest-magnitude priority number.
    - From last-evaluated to earliest-evaluated macro.
    - From closest-binding operators to loosest-binding operators
      (In C language: From "high precedence" to "low precedence" operators)
*)

let builtinMacros = [
    (* Weird grouping *)

    R(20.), "`", backtick;

    (* More boolean *)
    R(30.), "!", makePrefixUnary "not";

    (* Math *)
    R(30.), "~", makeUnary    "negate";
    R(40.), "/", makeSplitter "divide";
    R(40.), "*", makeSplitter "times";
    R(50.), "-", makeSplitter "minus";
    R(50.), "+", makeSplitter "plus";

    (* Comparators *)
    R(60.), "<", makeSplitter "lt";
    R(60.), "<=", makeSplitter "lte";
    R(65.), ">", makeSplitter "gt";
    R(65.), ">=", makeSplitter "gte";

    R(65.), "==", makeSplitter "eq";
    R(65.), "!=", makeSplitterInvert "eq";

    (* Boolean *)
    R(70.), "&&", makeSplitter "and";
    R(75.), "||", makeSplitter "or";

    (* Grouping *)
    L(90.), ":", applyRight;
    L(90.), "?", question;

    (* Core *)
    L(100.), "^",  closureConstruct true;
    L(100.), "^!", closureConstruct false;
    L(105.), "=",  assignment;
    L(110.), ".",  atom;
]

(* Populate macro table from builtinMacros. *)
let () =
    List.iter (function
        (priority, key, specFunction) -> Hashtbl.replace macroTable key {priority; specFunction}
    ) builtinMacros
