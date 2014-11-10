type codePosition = {
    fileName : string option;
    lineNumber : int;
}

type tokenGroupKind =
    | Plain                        (* Parenthesis *)
    | Scoped                       (* Create a new scope within this group *)
    | Box                          (* Create a new object *)
    | Closure                      (* No-argument function-- appears post-macro only *)
    | ClosureWithBinding of string (* Function with argument-- appears post-macro only *)

type tokenGroup = {
    kind : tokenGroupKind; (* Group kind and closure binding, if any *)
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

let makeToken file line contents = {
    at = { fileName=file; lineNumber=line };
    contents = contents;
}

let makeGroup file line kind items = 
    makeToken file line ( Group { kind=kind; items=items; } )

let rec dumpTree token =
    match token.contents with
    | Word x | Symbol x -> x
    | String x -> "\"" ^ x ^ "\""
    | Atom x -> "." ^ x
    | Number x -> string_of_float x
    | Group {kind=kind; items=items} ->
        let l, r = match kind with
            | Plain -> "(", ")"
            | Scoped -> "{", "}"
            | Box -> "[", "]"
            | Closure -> "^{", "}"
            | ClosureWithBinding binding -> "^" ^ binding ^ "{", "}"
        in l ^ ( String.concat "; " (
                let eachline x = String.concat " " ( List.map dumpTree x )
                in List.map eachline items;
        ) ) ^ r