(* Macro processing *)

(* Last thing we always do is make sure no symbols survive after macro processing. *)
let verifySymbols l =
    List.iter (function
        | {Token.contents=Token.Symbol s;Token.at=at} -> failwith @@ "Unrecognized symbol "^ s ^" at " ^ Token.positionString at
        | _ -> ()
    ) l;
    l

(* Types for macro processing. *)
type macroPriority = L of float | R of float
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
let standardClosure = Token.makeGroup Token.noPosition (Token.ClosureWithBinding []) Token.Plain
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
                | [] -> bestLine

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
                            | None,_ -> true
                            | Some L _,R _ -> false  | Some R _,L _ -> true
                            | Some L(left),L(right) -> left < right
                            | Some R(left),R(right) -> right <= left
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

(* A recurring pattern in the current macros is to insert a new single token
   into "the middle" of an established past and future *)
let arrange past present future =
    [ newFuture @@ List.concat [List.rev past; [newFuture present]; future] ]

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

(* One-off macros *)

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
let question past _ future =
    match past with
        | cond :: distantPast -> (
            match future with
                | a :: b :: farFuture ->
                    arrange distantPast [standardToken @@ Token.Word "tern";
                        cond; standardClosure [[a]]; standardClosure [[b]]
                    ] farFuture
                | _ -> failwith "? must be followed by two symbols" )
        | _ -> failwith "? must be preceded by two symbols"

(* Assignment operator-- semantics are relatively complex. TODO: Docs. *)
let assignment past _ future =
    (* The final parsed assignment will consist of a list of normal assignments
       and a list of ^ variables for a function. Perform that assignment here: *)
    let result lookups bindings =
        (* The token to be eventually assigned is easy to compute early, so do that. *)
        let rightside = match bindings with
            (* No bindings; this is a normal assignment. *)
            | [] -> newFuture future

            (* Bindings exist: This is a function definition. *)
            | _  -> Token.makeGroup Token.noPosition (Token.ClosureWithBinding bindings)
                    Token.Plain [process future]

        (* Done with bindings now, just have to figure out what we're assigning to *)
        in match lookups with
            (* ...Nothing? *)
            | [] -> failwith "Found a =, but nothing to assign to."

            (* Looks like a = b *)
            | [{Token.contents=Token.Word name}] ->   [standardToken @@ Token.Word "let"; standardToken @@ Token.Atom name; rightside]

            (* Looks like a b = c *)
            (* | a :: rest -> [standardToken @@ Token.Atom name; standardToken @@ Token.Atom "let"; b; rightside] *)

            (* Apparently did something like a.b.c.d = *)
            | _ -> failwith "= operator can't handle more than two left-side tokens yet."

    (* Parsing loop, build the lookups and bindings list *)
    in let rec processPast remainingPast lookups bindings =
        match remainingPast with
            (* Pull out any ^variable bindings, toss them in bindings *)
            | {Token.contents=Token.Word b} :: {Token.contents=Token.Symbol "^"} :: restPast -> (
                match lookups with
                    (* Check to make sure lookups is empty before proceeding *)
                    | [] -> processPast restPast lookups (b::bindings)

                    (* You can't mix bound and unbound identifiers in a let, that's strange *)
                    | x  -> failwith "Found an expression to the left of a = but to the right of a ^. Only variable bindings are allowed in that space."
                )

            (* Sanitize any symbols that aren't cleared for the left side of an = *)
            | {Token.contents=Token.Symbol x} :: _ -> failwith @@ "Unexpected symbol "^x^" to left of ="

            (* Pull out something that isn't a binding, toss it in lookups *)
            | l :: restPast -> processPast restPast (l::lookups) bindings

            (* There is no more past, Jump to result. *)
            | [] -> result lookups bindings

    (* Begin *)
    in processPast past [] []

(* Match-left-first is interpreted before match-right-first; low priority before high priority. *)
(* Note this produces the opposite effect of "associativity" and "precedence" from, say, C. *)

let builtinMacros = [

    (* Assignment *)
    L(10.), "=",  assignment;

    (* Grouping *)
    L(20.), "?", question;
    L(25.), ":", applyRight;

    (* Boolean *)
    R(40.), "||", makeSplitter "or";
    R(45.), "&&", makeSplitter "and";

    (* Math *)
    R(50.), "+", makeSplitter "plus";
    R(50.), "-", makeSplitter "minus";
    R(60.), "*", makeSplitter "times";
    R(60.), "/", makeSplitter "divide";
    R(70.), "~", makeUnary    "negate";

    (* More booelan *)
    R(70.), "!", makePrefixUnary "not";

    (* Weird grouping *)
    R(90.), "`", backtick;
]

(* Populate macro table from builtinMacros. *)
let () =
    List.iter (function
        (priority, key, specFunction) -> Hashtbl.replace macroTable key {priority; specFunction}
    ) builtinMacros
