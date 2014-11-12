(* Records the original source position of a token *)
type codePosition = {
    fileName : string option;
    lineNumber : int;
    lineOffset : int;
}

(* Make codePosition.fileName human-readable *)
let fileNameString n = (match n with None -> "<Input>" | Some s -> s)

(* Make codePosition human-readable *)
let positionString p = Printf.sprintf "[%s line %d ch %d]"
    (fileNameString p.fileName) p.lineNumber p.lineOffset

(* What are the rules for descending into this group? *)
type tokenGroupKind =
    | Plain                        (* Parenthesis *)
    | Scoped                       (* Create a new scope within this group *)
    | Box                          (* Create a new object *)

(* Is this group a closure? What kind? *)
type tokenClosureKind =
    | NonClosure                   (* Is not a function *) 
    | Closure                      (* No-argument function-- should appear post-macro only *)
    | ClosureWithBinding of string (* Function with argument-- should appear post-macro only *)

(* Representation of a tokenized code blob. *)
(* A codeSequence is a list of lines. A line is a list of tokens. *)
(* A token may be a group with its own codeSequence. *)
type codeSequence = token list list

(* Data content of a group-type token *)
and tokenGroup = {
    kind : tokenGroupKind;      (* Group kind *)
    closure : tokenClosureKind;  (* Closure kind, if any *)
    items : codeSequence; (* Group is a list of lines, lines are a list of tokens *)
}

(* Data content of a token *)
and tokenContents = 
    | Word of string   (* Alphanum *)
(*  | Symbol of string    Punctuation-- appears pre-macro only. Disabled until macros are back *)
    | String of string (* "Quoted" *)
    | Atom   of string (* Appears post-macro only *)
    | Number of float
    | Group of tokenGroup

(* A token. Effectively, an AST node. *)
and token = {
    at : codePosition;
    contents : tokenContents;
}

(* Quick constructor for token *)
let makeToken position contents = {
    at = position;
    contents = contents;
}

(* Quick constructor for token, group type *)
let makeGroup position closure kind items = 
    makeToken position ( Group { kind=kind; closure=closure; items=items; } )

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
