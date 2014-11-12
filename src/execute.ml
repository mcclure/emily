type registerState = 
    | LineStart of Value.value
    | FirstValue of Value.value
    | PairValue of (Value.value * Value.value)

type executeFrame = {
    code : Token.codeSequence;
    register : registerState;
    (* TODO: Scope *)
}

(* Is there gonna be more here later? *)
and executeState = executeFrame list

(* The general approach to evaluate a group is: For each line:
    1. If the line is empty, skip it.
    2. Take the first token, remove it from the line, evaluate it, call that Value 1.
    3. If there are no more tokens in the line, the remaining Value 1 is the value of the line.
    4. Take the next remaining token, remove it from the line, evaluate it, call that Value 2.
    5. Apply Value 1 to Value 2, make the result the new Value 1. Goto 2.
    The value of the final nonempty line is the value returned from evaluating the group.
    Steps 2, 4 and 5 could potentially require code invocation, necessitating the stack.
 *)

let execute code =
    let initialExecuteState initial = [{code = initial; register = LineStart(Value.Null)}] in
    let rec execute_step stack =
        let return v = () in
        let internalFail () = failwith "Internal consistency error: Reached impossible place" in
        match stack with
            | [] -> () (* Nothing to do *)
            | frame :: moreframes ->
            match frame.code with
                | [] -> let value = match frame.register with
                    | LineStart v | FirstValue v -> v
                    | _ -> internalFail()
                in return value (* End of reached. *)
                | line :: morelines -> match line with
                    (* end of line, but more lines. just move on. *)
                    | [] -> execute_step stack

                    (* apply last to token *)
                    | token :: moretokens ->
                        let simpleValue v =
                            let newState = match frame.register with
                                | LineStart _ -> FirstValue (v)
                                | FirstValue fv -> PairValue (fv, v)
                                | _ -> internalFail()
                            in execute_step @@ { register=newState; code=moretokens::morelines; } :: moreframes
                        (* Evaluate token *)
                        in match token.Token.contents with
                            | Token.Word s -> failwith "Can't read from scope yet" (* TODO: Create a value from a token. *)
                            | Token.String s -> simpleValue(Value.StringValue s)
                            | Token.Atom s ->   simpleValue(Value.AtomValue s)
                            | Token.Number f -> simpleValue(Value.FloatValue f)
                            | Token.Group descent -> 
                                execute_step @@ initialExecuteState descent.Token.items
    in match code.Token.contents with
        | Token.Group contents -> execute_step @@ initialExecuteState contents.Token.items
        | _ -> () (* Execute a constant value-- no effect *)
