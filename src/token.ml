type codePosition = {
    fileName : string option;
    lineNumber : int;
}

type tokenGroupKind = 
    Plain | Scoped | Box

type tokenGroupKind =
    | Plain                        (*  *)
    | Scoped                       (*  *)
    | Box                          (*  *)
    | Closure                      (* No-argument function *)
    | ClosureWithBinding of string (* Function with argument *)

type tokenGroup = {
    kind : tokenGroupKind; (* Group kind and closure data, if any *)
    items : tokenContents array;
}
and tokenContents = 
    | Word of string   (* Alphanum *)
    | Symbol of string (* Punctuation-- must be macro'd out by execution time *)
    | String of string (* "Quoted" *)
    | Atom   of string (* Potentially cannot be created except by macros *)
    | Number of float
    | Group of tokenGroup

type token = {
    at : codePosition;
    contents : tokenContents;
}
