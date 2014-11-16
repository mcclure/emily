(* TODO: Put these in their own file? *)
(* "Disassemble" a token tree into a human-readable string (specializable) *)
let rec dumpTree groupPrinter token =
    match token.Token.contents with
    (* For a simple (nongrouping) token, return a string for just the item *)
    | Token.Word x (* | Symbol x *) -> x
    | Token.String x -> "\"" ^ x ^ "\""
    | Token.Atom x -> "." ^ x
    | Token.Number x -> string_of_float x
    | Token.Group {Token.kind=kind; closure=closure; items=items} ->
        let l, r = match kind with
            | Token.Plain -> "(", ")"
            | Token.Scoped -> "{", "}"
            | Token.Box -> "[", "]"
        in let l = (match closure with 
            | Token.NonClosure -> ""
            | Token.Closure -> "^"
            | Token.ClosureWithBinding binding -> "^" ^ binding) ^ l
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
    let rec oneToken x = Printf.sprintf "%s %s" (Token.positionString x.Token.at) (dumpTree groupPrinter x)
    and groupPrinter token l r items =
        l ^ "\n" ^ ( String.concat "\n" (
                    let eachline x = String.concat "\n" ( List.map oneToken x )
                    in List.map eachline items;
        ) ) ^ "\n" ^ r
    in dumpTree groupPrinter token

let dumpValue v =
    match v with 
        | Value.Null -> "<null>"
        | Value.True -> "<true>"
        | Value.FloatValue v -> string_of_float v
        | Value.StringValue s -> s
        | Value.AtomValue s -> s
        | Value.BuiltinFunctionValue _ -> "<builtin>"
        | Value.BuiltinMethodValue _ -> "<object-builtin>" 
        | Value.ClosureValue _ -> "<closure>"
        | Value.TableValue _ -> "<map>"
