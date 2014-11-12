type executeState = {
    (* List of tokens (current rest-of-line) *)
    (* List of lines  (current rest-of-group) *)
    (* List of groups (backtrace) *)
    stack : Token.token list list list;

    (* Current operating value *)
    last : Value.value
}

type mode = Start | Continue

let execute ast =
    let initialExecuteState initial = {stack = [initial]; last = Value.Null} in
    let rec execute_step mode state =
        let {stack=stack;last=last} = state in
        match stack with
            | [] -> ()
            | frame :: moreframes ->
            match frame with
                | [] -> ()
                | line :: morelines ->
                match line with
                    (* end of line, but more lines. just move on. *)
                    | [] -> execute_step Start state

                    (* apply last to token *)
                    | token :: moretokens ->
                        match mode with Start -> execute_step Continue { last=Value.Null; (* TODO: Eval *)
                                stack = (moretokens :: morelines) :: moreframes }
                        | Continue -> (* TODO: Eval *)
                        ()
    in match ast.Token.contents with
        | Token.Group contents -> execute_step Start (initialExecuteState contents.Token.items)
        | _ -> () (* Execute a constant value-- no effect *)