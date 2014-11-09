type codePosition = {
	fileName : string option;
	lineNumber : int;
}

type tokenGroupKind = 
	Plain | Scoped | Box

type tokenGroupBinding =
	| Inline  (* Not a closure *)
	| Nullary (* No argument *)
	| Binding of string (* Argument *)

type tokenGroup = {
	binding : tokenGroupBinding; (* Is this a closure? Does it have an argument? *)
	kind : tokenGroupKind;
	items : tokenContents list;
	(* Array? *)
}
and tokenContents = 
	| Word of string   (* Alphanum *)
	| Symbol of string (* Punctuation *)
	| String of string (* "Quoted" *)
	| Atom   of string (* Potentially cannot be created except by macros *)
	| Number of float
	| Group of tokenGroup

type token = {
	at : codePosition;
	contents : tokenContents
}
