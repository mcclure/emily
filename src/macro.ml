(* Macro processing *)

let verifySymbols l =
    List.iter (function
        | {Token.contents=Token.Symbol s;Token.at=at} -> failwith @@ "Unrecognized symbol "^ s ^" at " ^ Token.positionString at
        | _ -> ()
    ) l;
    l

type macroPriority = L of float | R of float
type singleLine = Token.token list
type macroFunction = singleLine -> Token.token -> singleLine -> singleLine
type macroSpec  = { priority : macroPriority ; specFunction : macroFunction }
type macroMatch = {
    matchFunction: macroFunction ;
    past : singleLine; present : Token.token; future : singleLine
}

let macroTable = Hashtbl.create(1)

(* TODO: No no no I want positions *)
let standardGroup = Token.makeGroup Token.noPosition Token.NonClosure Token.Plain
let standardClosure = Token.makeGroup Token.noPosition (Token.ClosureWithBinding []) Token.Plain
let standardToken = Token.makeToken Token.noPosition

let rec process l =
    if Options.(run.stepMacro) then print_endline @@ Pretty.dumpCodeTreeTerse @@ standardGroup [l];
    let rec findIdeal (bestPriority:macroPriority option) bestLine (past:singleLine) present future : macroMatch option =
        let proceed priority line =
            match future with
                | [] -> bestLine
                | nextToken :: nextFuture -> findIdeal priority line (present::past) nextToken nextFuture
        in let skip() =
            proceed bestPriority bestLine
        in match present.Token.contents with
            | Token.Word s | Token.Symbol s ->
                let v = CCHashtbl.get macroTable s in
                (match v with
                | Some {priority;specFunction} ->
                    let better = (match bestPriority,priority with
                        | None,_ -> true
                        | Some L _,R _ -> false  | Some R _,L _ -> true
                        | Some L(left),L(right) -> left < right
                        | Some R(left),R(right) -> right <= left
                    ) in
                    if better then
                        proceed (Some priority) (Some {past; present; future; matchFunction=specFunction})
                    else skip()
                | _ -> skip() )
            | _ -> skip()

    in match l with | [] -> l
        | present::future ->
            (match findIdeal None None [] present future with
                | None -> verifySymbols l
                | Some {matchFunction; past; present; future} ->
                    if Options.(run.stepMacro) then print_endline @@ "    ...becomes:";
                    process (matchFunction past present future) )

(* Macros *)

let newFuture f = standardGroup [process f] (* Insert a forward-time group *)
let newPast p   = newFuture (List.rev p)    (* Insert a reverse-time group *)

let arrange past present future =
    [ newFuture @@ List.concat [List.rev past; [newFuture present]; future] ]

let makeSplitter atomString : macroFunction = (fun past _ future ->
    [ newPast past ; standardToken @@ Token.Atom atomString ; newFuture future]
)

let makeUnary atomString : macroFunction = (fun past present future ->
    match future with
        | a :: farFuture ->
            arrange past [a; standardToken @@ Token.Atom atomString] farFuture
        | _ -> failwith @@ (Pretty.dumpCodeTreeTerse present) ^ " must be followed by a symbol"
)

let makePrefixUnary wordString : macroFunction = (fun past present future ->
    match future with
        | a :: farFuture ->
            arrange past [standardToken @@ Token.Word wordString; a] farFuture
        | _ -> failwith @@ (Pretty.dumpCodeTreeTerse present) ^ " must be followed by a symbol"
)

(* Unused. TODO: Use this for a future "and" in the global namespace? *)
let makeSplitterPrefix wordString : macroFunction = (fun past _ future ->
    [ standardToken @@ Token.Word wordString ; newPast past ; newFuture future ]
)

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

let assignment past _ future =
    let result lookups bindings =
        let rightside = match bindings with
            | [] -> newFuture future
            | _  -> Token.makeGroup Token.noPosition (Token.ClosureWithBinding bindings)
                    Token.Plain [process future]
        in match lookups with
            | [] -> failwith "Found a =, but nothing to assign to."
            | [{Token.contents=Token.Word name}] ->   [standardToken @@ Token.Word "let"; standardToken @@ Token.Atom name; rightside]
(* | a :: rest -> [standardToken @@ Token.Atom name; standardToken @@ Token.Atom "let"; b; rightside] *)
            | _ -> failwith "= operator can't handle more than two left-side tokens yet."
    in let rec processPast remainingPast lookups bindings : Token.token list =
        match remainingPast with
            | {Token.contents=Token.Word b} :: {Token.contents=Token.Symbol "^"} :: restPast -> (
                match lookups with
                    | [] -> processPast restPast lookups (b::bindings)
                    | x  -> failwith "Found an expression to the left of a = but to the right of a ^. Only variable bindings are allowed in that space."
                )
            | {Token.contents=Token.Symbol x} :: _ -> failwith @@ "Unexpected symbol "^x^" to left of ="
            | l :: restPast -> processPast restPast (l::lookups) bindings
            | [] -> result lookups bindings
    in processPast past [] []

(* Match-left-first is interpreted before match-right-first; low priority before high priority. *)
(* Note this produces the opposite effect of "associativity" and "precedence" from, say, C. *)

let builtinMacros = [

    (* Assignment *)


    (* Grouping *)
    L(20.), "?", question;
    L(25.), ":", applyRight;

    L(10.), "=",  assignment;
    (* Boolean *)
    R(40.), "||", makeSplitter "or";
    R(45.), "&&", makeSplitter "and";

    (* Math *)
    R(50.), "+", makeSplitter "plus";
    R(50.), "-", makeSplitter "minus";
    R(60.), "*", makeSplitter "times";
    R(60.), "/", makeSplitter "divide";
    R(70.), "~", makeUnary    "negate";

    R(70.), "!", makePrefixUnary "not";

    (* Weird grouping *)
    R(90.), "`", backtick;
]

let () =
    List.iter (function
        (priority, key, specFunction) -> Hashtbl.replace macroTable key {priority; specFunction}
    ) builtinMacros
