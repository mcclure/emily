let verifySymbols l =
    List.iter (function
        | {Token.contents=Token.Symbol s;Token.at=at} -> failwith @@ "Unrecognized symbol "^ s ^" at " ^ Token.positionString at
        | _ -> ()
    ) l;
    l

let process l =
    l
