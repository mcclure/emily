(* TODO: Put these in their own file? *)
(* "Disassemble" a token tree into a human-readable string (specializable) *)
let rec dumpTree groupPrinter token =
    match token.contents with
    (* For a simple (nongrouping) token, return a string for just the item *)
    | Word x (* | Symbol x *) -> x
    | String x -> "\"" ^ x ^ "\""
    | Atom x -> "." ^ x
    | Number x -> string_of_float x
    | Group {kind=kind; closure=closure; items=items} ->
        let l, r = match kind with
            | Plain -> "(", ")"
            | Scoped -> "{", "}"
            | Box -> "[", "]"
        in let l = (match closure with 
            | NonClosure -> ""
            | Closure -> "^"
            | ClosureWithBinding binding -> "^" ^ binding) ^ l
        (* GroupPrinter is an argument function which takes the left group symbol, right group
           symbol, and group contents, and decides how to format them all. *)
        in groupPrinter token l r items

(* "Disassemble" a token tree into a human-readable string (specialized for looking like code) *)
let dumpTreeTerse token =
    let rec groupPrinter token l r items =
        l ^ ( String.concat "; " (
                    let eachline x = String.concat " " ( List.map (dumpTree groupPrinter) x )
                    in List.map eachline items;
        ) ) ^ r
    in dumpTree groupPrinter token

(* "Disassemble" a token tree into a human-readable string (specialized to show token positions) *)
let dumpTreeDense token =
    let rec oneToken x = Printf.sprintf "%s %s" (positionString x.at) (dumpTree groupPrinter x)
    and groupPrinter token l r items =
        l ^ "\n" ^ ( String.concat "\n" (
                    let eachline x = String.concat "\n" ( List.map oneToken x )
                    in List.map eachline items;
        ) ) ^ "\n" ^ r
    in dumpTree groupPrinter token
