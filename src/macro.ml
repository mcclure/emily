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

(* Pair operator-- Works like ocaml @@ or haskell $ *)
let applyRight past _ future =
    [ newPast @@ newFuture future :: past ]

(* Works like ocaml @@ or haskell $ *)
let backtick past _ future =
    match future with
        | a :: b :: farFuture ->
            arrange past [a;b] farFuture
        | _ -> failwith "` must be followed by two symbols"

(* Match-left-first is interpreted before match-right-first; low priority before high priority. *)
(* Note this produces the opposite effect of "associativity" and "precedence" from, say, C. *)

let builtinMacros = [

    (* Assignment *)

    (* Grouping *)
    L(2.), ":", applyRight;

    (* Math *)
    R(3.), "+", makeSplitter "plus";
    R(3.), "-", makeSplitter "minus";
    R(4.), "*", makeSplitter "times";
    R(4.), "/", makeSplitter "divide";
    R(5.), "~", makeUnary    "negate";

    (* Weird grouping *)
    R(10.), "`", backtick;
]

let () =
    List.iter (function
        (priority, key, specFunction) -> Hashtbl.replace macroTable key {priority; specFunction}
    ) builtinMacros
