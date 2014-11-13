(* The general approach to evaluate a group is: For each line:
    1. If the line is empty, skip it.
    2. Take the first token, remove it from the line, evaluate it, call that Value 1.
    3. If there are no more tokens in the line, the remaining Value 1 is the value of the line.
    4. Take the next remaining token, remove it from the line, evaluate it, call that Value 2.
    5. Apply Value 1 to Value 2, make the result the new Value 1. Goto 2.
    The value of the final nonempty line is the value returned from evaluating the group.
    Steps 2, 4 and 5 could potentially require code invocation, necessitating the stack.
 *)

(* We imagine values 1 and 2 as "registers"... *)
type registerState = 
    | LineStart of Value.value
    | FirstValue of Value.value
    | PairValue of (Value.value * Value.value)

(* Each frame on the stack has the two value "registers" and a codeSequence reference which
   is effectively an instruction pointer. *)
type executeFrame = {
    code : Token.codeSequence;
    register : registerState;
    (* TODO: Scope *)
}

(* The current state of an execution thread consists of just the stack. (Is there gonna be more here later?) *)
and executeState = executeFrame list

(* Execute and return nothing. *)
let execute code =
    (* Constructor for a new, stateless frame beginning with the given code-position reference *)
    let initialExecuteState initial = [{code = initial; register = LineStart(Value.Null)}] in

    (* Main loop *)
    let rec execute_step stack =
        (* Pop a frame from the stack, integrate the result into the last frame and recurse (TODO) *)
        let return v = () in

        (* For nonsensical matches *)
        let internalFail () = failwith "Internal consistency error: Reached impossible place" in

        (* TODO: If PairValue, don't bother with stack and handle that *)

        (* Look at stack *)
        match stack with
            (* Asked to execute an empty group -- just return *)
            | [] -> ()

            (* Break stack frames into first and rest *)
            | frame :: moreframes ->

                (* Look at code sequence in frame *)
                match frame.code with
                    (* It's empty. We have reached the end of the group. *)
                    | [] -> let value = match frame.register with (* Unpack Value 1 from register *)
                            | LineStart v | FirstValue v -> v
                            | _ -> internalFail() (* If PairValue, should have branched off above *)
                        (* Return from frame *)
                        in return value

                    (* Break lines in current frame's codeSequence into first and rest *)
                    | line :: morelines ->

                        (* Look at line in code sequence. *)
                        match line with
                            (* It's empty. We have reached the end of the line. *)
                            | [] ->
                                (* Convert Value 1 to a LineStart value to persist to next line *)
                                let newState = match frame.register with
                                    | LineStart v | FirstValue v -> LineStart v
                                    | _ -> internalFail() (* Again: if PairValue, should have branched off above *)

                                (* Replace current frame, new code sequence is rest-of-lines, and recurse *)
                                in execute_step @@ { register=newState; code=morelines; } :: moreframes

                            (* Break tokens in current line into first and rest *)
                            | token :: moretokens ->
                                (* Helper: Given a value, and knowing register state, make a new register state and recurse *)
                                let simpleValue v =
                                    (* ...new register state... *)
                                    let newState = match frame.register with
                                        (* Either throw out a LineStart and simply take the new value, *)
                                        | LineStart _ -> FirstValue (v)
                                        (* Or combine with an existing value to make a pair. *)
                                        | FirstValue fv -> PairValue (fv, v)
                                        | _ -> internalFail()
                                    (* Replace current line by replacing current frame, new line is rest-of-line, and recurse *)
                                    in execute_step @@ { register=newState; code=moretokens::morelines; } :: moreframes

                                (* Evaluate token *)
                                in match token.Token.contents with
                                    (* Straightforward values that can be evaluated in place *)
                                    | Token.Word s -> failwith "Can't read from scope yet" (* TODO: Create a value from a token. *)
                                    | Token.String s -> simpleValue(Value.StringValue s)
                                    | Token.Atom s ->   simpleValue(Value.AtomValue s)
                                    | Token.Number f -> simpleValue(Value.FloatValue f)

                                    (* Token is nontrivial to evaluate, and will require a new stack frame. *)
                                    | Token.Group descent -> 
                                        execute_step @@ initialExecuteState descent.Token.items
    in match code.Token.contents with
        | Token.Group contents -> execute_step @@ initialExecuteState contents.Token.items
        | _ -> () (* Execute a constant value-- no effect *)
