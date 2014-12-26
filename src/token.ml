(* Data representation for an AST. *)

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
    | NonClosure                        (* Is not a function *)
    | ClosureWithBinding of string list (* Function with argument-- ideally should appear post-macro only *)

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
    | Symbol of string (* Punctuation-- appears pre-macro only. *)
    | String of string (* "Quoted" *)
    | Atom   of string (* Ideally appears post-macro only *)
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

let noPosition = {fileName=None;lineNumber=0;lineOffset=0}

let makePositionless contents = {at=noPosition; contents=contents}