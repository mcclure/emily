(* Pretty-printers for types from various other files *)

(* --- Code printers --- *)

(* "Disassemble" a token tree into a human-readable string (specializable) *)
let rec dumpCodeTreeGeneral groupPrinter token =
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
            | Token.ClosureWithBinding [] -> "^"
            | Token.ClosureWithBinding binding -> "^" ^ (String.concat " " binding)) ^ l
        (* GroupPrinter is an argument function which takes the left group symbol, right group
           symbol, and group contents, and decides how to format them all. *)
        in groupPrinter token l r items

(* "Disassemble" a token tree into a human-readable string (specialized for looking like code) *)
let dumpCodeTreeTerse token =
    let rec groupPrinter token l r items =
        l ^ ( String.concat "; " (
                    let eachline x = String.concat " " ( List.map (dumpCodeTreeGeneral groupPrinter) x )
                    in List.map eachline items;
        ) ) ^ r
    in dumpCodeTreeGeneral groupPrinter token

(* "Disassemble" a token tree into a human-readable string (specialized to show token positions) *)
let dumpCodeTreeDense token =
    let rec oneToken x = Printf.sprintf "%s %s" (Token.positionString x.Token.at) (dumpCodeTreeGeneral groupPrinter x)
    and groupPrinter token l r items =
        l ^ "\n" ^ ( String.concat "\n" (
                    let eachline x = String.concat "\n" ( List.map oneToken x )
                    in List.map eachline items;
        ) ) ^ "\n" ^ r
    in dumpCodeTreeGeneral groupPrinter token

(* --- Value printers --- *)

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

let dumpValueTreeGeneral wrapper v =
    match v with
        | Value.Null -> "<null>"
        | Value.True -> "<true>"
        | Value.FloatValue v -> string_of_float v
        | Value.StringValue s -> quoteWrap s
        | Value.AtomValue s -> "." ^ s
        | Value.BuiltinFunctionValue _ -> "<builtin>"
        | Value.BuiltinMethodValue _ -> "<object-builtin>"
        | Value.ClosureValue {Value.exec=e; Value.needArgs=n} ->
            let tag = match e with Value.ClosureExecUser _ -> "closure" | Value.ClosureExecBuiltin _ -> "closure-builtin" in
             "<" ^ tag ^ "/" ^ string_of_int(n) ^">"
        | Value.TableValue    _ -> wrapper "table" v

let dumpValue v =
    let simpleWrapper label obj = angleWrap label
    in let labelWrapper label obj = match obj with
        | Value.TableValue t -> angleWrap @@ label ^ ":" ^ (idStringForTable t)
        | _ -> angleWrap label
    in let wrapper = if Options.(run.trackObjects) then labelWrapper else simpleWrapper

    in dumpValueTreeGeneral wrapper v

(* FIXME: The formatting here is not even a little bit generalized. *)
let dumpValueTable v =
    dumpValue (v) ^ match v with
        | Value.TableValue t -> " = [\n            " ^
            (String.concat "\n            " (List.map (function
                (v1, v2) -> dumpValue(v1) ^ " = " ^ dumpValue(v2)
            ) (CCHashtbl.to_list t) ) ) ^ "\n        ]"
        | _ -> ""

let dumpValueNewTable v =
    (if Options.(run.traceSet) then dumpValueTable else dumpValue) v

(* Normal "print" uses this *)
let dumpValueForUser v =
    match v with
        | Value.StringValue s -> s
        | Value.AtomValue s -> s
        | _ -> dumpValue v
