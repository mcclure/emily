(* Pretty-printers for types from various other files *)

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

let angleWrap s = "<" ^ s ^ ">"
let quoteWrap s = "\"" ^ s ^ "\""
let idStringForTable t =
    match Value.tableGet t Value.idKey with
        | None -> "UNKNOWN"
        | Some Value.FloatValue v -> string_of_int @@ int_of_float v
        | _ -> "INVALID" (* Should be impossible *)
let idStringForValue v = match v with
    | Value.TableValue t -> idStringForTable t
    | _ -> "UNTABLE"

let dumpValueTreeImpl wrapper v =
    match v with
        | Value.Null -> "<null>"
        | Value.True -> "<true>"
        | Value.FloatValue v -> string_of_float v
        | Value.StringValue s -> quoteWrap s
        | Value.AtomValue s -> "." ^ s
        | Value.BuiltinFunctionValue _ -> "<builtin>"
        | Value.BuiltinMethodValue _ -> "<object-builtin>"
        | Value.ClosureValue _ -> "<closure>"
        | Value.TableValue _ -> wrapper "table" v
        | Value.TableHasValue _ -> wrapper "table-checker-has" v
        | Value.TableSetValue _ -> wrapper "table-setter" v
        | Value.TableLetValue _ -> wrapper "table-setter-let" v

let dumpValueTree v =
    let rec wrapper label obj = match obj with
        | Value.TableValue t | Value.TableSetValue t | Value.TableLetValue t -> angleWrap @@ label ^ ":" ^ (idStringForTable t)
        | _ -> angleWrap label
    in dumpValueTreeImpl wrapper v

let dumpValue v =
    let wrapper label obj = angleWrap label
    in dumpValueTreeImpl wrapper v

(* Normal "print" uses this *)
let dumpValueForUser v =
    match v with
        | Value.StringValue s -> s
        | Value.AtomValue s -> s
        | _ -> dumpValue v
