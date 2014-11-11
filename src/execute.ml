type executeState = {
	(* List of tokens (current rest-of-line) *)
	(* List of lines  (current rest-of-group) *)
	(* List of groups (backtrace) *)
	stack : Token.token list list list;

	(* Current operating value *)
	last : Value.value
}

let execute ast =
	()