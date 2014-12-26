(* Macro processing *)

let verifySymbols l =
    List.iter (function
        | {Token.contents=Token.Symbol s;Token.at=at} -> failwith @@ "Unrecognized symbol "^ s ^" at " ^ Token.positionString at
        | _ -> ()
    ) l;
    l

type singleLine = Token.token list
type macroFunction = singleLine -> Token.token -> singleLine -> singleLine
type macroSpec  = { priority : float ; specFunction : macroFunction }
type macroMatch = {
    matchFunction: macroFunction ;
    past : singleLine; present : Token.token; future : singleLine
}

let macroTable = Hashtbl.create(1)

let rec process l =
    let rec findIdeal bestScore bestLine (past:singleLine) present future : macroMatch option =
        let proceed score line =
            match future with
                | [] -> bestLine
                | nextToken :: nextFuture -> findIdeal score line (present::past) nextToken nextFuture
        in let skip() =
            proceed bestScore bestLine
        in match present.Token.contents with
            | Token.Word s | Token.Symbol s ->
                let v = CCHashtbl.get macroTable s in
                (match v with
                | Some ({priority=score;specFunction=specFunction} as line) ->
                    if score < bestScore then
                        proceed score (Some {past=past; present=present; future=future; matchFunction=specFunction})
                    else skip()
                | _ -> skip() )
            | _ -> skip()

    in match l with | [] -> l
        | present::future ->
            (match findIdeal (-1.0) None [] present future with
                | None -> verifySymbols l
                | Some {matchFunction=matchFunction; past=past; present=present; future=future} ->
                    process (matchFunction past present future) )

(* Macros *)

(* TODO: No no no I want positions *)
let standardGroup = Token.makeGroup Token.noPosition Token.NonClosure Token.Plain
let standardToken = Token.makeToken Token.noPosition

let newFuture f = standardGroup [process f]
let newPast p   = newFuture (List.rev p)

let makeSplitter atomString : macroFunction = (fun past present future ->
    [ newPast past ; standardToken @@ Token.Atom atomString ; newFuture future]
)

let builtinMacros = [
    3., "+", makeSplitter "plus";
    3., "-", makeSplitter "minus";
    4., "*", makeSplitter "times";
    4., "/", makeSplitter "divide";
]

let () =
    List.iter (function
        (priority, key, specFunction) -> Hashtbl.replace macroTable key {priority=priority; specFunction=specFunction}
    ) builtinMacros
