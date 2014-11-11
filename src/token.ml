type codePosition = {
    fileName : string option;
    lineNumber : int;
    lineOffset : int;
}

let fileNameString n = (match n with None -> "<Input>" | Some s -> s)

let positionString p = Printf.sprintf "[%s line %d ch %d]"
    (fileNameString p.fileName) p.lineNumber p.lineOffset

type tokenGroupKind =
    | Plain                        (* Parenthesis *)
    | Scoped                       (* Create a new scope within this group *)
    | Box                          (* Create a new object *)

type tokenClosureKind =
    | NonClosure                   (* Is not a function *) 
    | Closure                      (* No-argument function-- should appear post-macro only *)
    | ClosureWithBinding of string (* Function with argument-- should appear post-macro only *)

type tokenGroup = {
    kind : tokenGroupKind;      (* Group kind *)
    closure : tokenClosureKind;  (* Closure kind, if any *)
    items : token list list; (* Group is a list of lines, lines are a list of tokens *)
}

and tokenContents = 
    | Word of string   (* Alphanum *)
    | Symbol of string (* Punctuation-- appears pre-macro only *)
    | String of string (* "Quoted" *)
    | Atom   of string (* Appears post-macro only *)
    | Number of float
    | Group of tokenGroup

and token = {
    at : codePosition;
    contents : tokenContents;
}

let makeToken position contents = {
    at = position;
    contents = contents;
}

let makeGroup position closure kind items = 
    makeToken position ( Group { kind=kind; closure=closure; items=items; } )

let rec dumpTree groupPrinter token =
    match token.contents with
    | Word x | Symbol x -> x
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
        in groupPrinter token l r items

let dumpTreeTerse token =
    let rec groupPrinter token l r items =
        l ^ ( String.concat "; " (
                    let eachline x = String.concat " " ( List.map (dumpTree groupPrinter) x )
                    in List.map eachline items;
        ) ) ^ r
    in dumpTree groupPrinter token

let dumpTreeDense token =
    let rec oneToken x = Printf.sprintf "%s %s" (positionString x.at) (dumpTree groupPrinter x)
    and groupPrinter token l r items =
        l ^ "\n" ^ ( String.concat "\n" (
                    let eachline x = String.concat "\n" ( List.map oneToken x )
                    in List.map eachline items;
        ) ) ^ "\n" ^ r
    in dumpTree groupPrinter token
