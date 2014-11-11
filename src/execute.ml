type executeState = {
	(* List of tokens (current rest-of-line) *)
	(* List of lines  (current rest-of-group) *)
	(* List of groups (backtrace) *)
	stack : Token.token list list list;

	(* Current operating value *)
	last : Value.value
}

let execute ast =
	let initialExecuteState initial = {stack = [initial]; last = Value.Null} in
	let execute_step state =
		()
	in match ast.Token.contents with
		| Token.Group contents -> execute_step (initialExecuteState contents.Token.items)
		| _ -> () (* Execute a constant value-- no effect *)