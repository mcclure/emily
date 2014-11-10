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
    items : tokenContents list list; (* Group is a list of lines, lines are a list of tokens *)
}
and tokenContents = 
    | Word of string   (* Alphanum *)
    | Symbol of string (* Punctuation-- appears pre-macro only *)
    | String of string (* "Quoted" *)
    | Atom   of string (* Appears post-macro only *)
    | Number of float
    | Group of tokenGroup

type token = {
    at : codePosition;
    contents : tokenContents;
}

let makeToken file line kind list = {
    at = { fileName=file; lineNumber=line };
    contents = Group { kind=kind; items=[[]]; };
}

let dumpTree token =
    match token.contents with
    | Word x | Symbol x | String x | Atom x -> x
    | Number x -> string_of_float x
    | Group {kind=kind; items=items} -> "GROUP"