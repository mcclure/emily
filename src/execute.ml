(* Functions to execute a codeSequence *)

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

let dumpPrinter = if Options.(run.trackObjects) then Pretty.dumpValueTree else Pretty.dumpValue

let dumpRegisterState registerState =
    match registerState with
    | LineStart v -> "LineStart:" ^ (dumpPrinter v)
    | FirstValue v -> "FirstValue:" ^ (dumpPrinter v)
    | PairValue (v1,v2) -> "PairValue:" ^ (dumpPrinter v1) ^ "," ^ (dumpPrinter v2)

(* Each frame on the stack has the two value "registers" and a codeSequence reference which
   is effectively an instruction pointer. *)
type executeFrame = {
    register : registerState;
    code : Token.codeSequence;
    scope: Value.value;
}

(* The current state of an execution thread consists of just the stack. (Is there gonna be more here later?) *)
and executeState = executeFrame list

let scopeInheriting kind v =
    Value.TableValue(Value.tableInheriting kind v)
let closureScope c =
    let scope = c.Value.scope in
    match (c.Value.scoped,c.Value.key) with
        | (true,_) -> scopeInheriting Value.WithLet scope
        | (false,Some _) -> scopeInheriting Value.NoLet scope
        | _ -> scope
let groupScope tokenKind scope =
    match tokenKind with
        | Token.Plain  -> scope
        | Token.Scoped -> scopeInheriting Value.WithLet scope
        | Token.Box    -> scopeInheriting (Value.BoxFrom (Some BuiltinObject.objectPrototype)) scope

let stackDepth stack =
    let rec stackDepthImpl accum stack =
        match stack with
            | [] -> accum
            | _::more -> stackDepthImpl (accum+1) more
    in stackDepthImpl 0 stack

let parentSetSnippet = Tokenize.snippet "target.parent.set key"
let parentHasSnippet = Tokenize.snippet "target.parent.has key"

(* Execute and return nothing. *)
(* TODO: This is too long, break up into more subfunctions... *)
let execute code =
    (* Constructor for a new, stateless frame beginning with the given code-position reference *)
    let executeFrame scope code = {register=LineStart(Value.Null); code=code; scope=scope} in
    let initialExecuteFrame = executeFrame (scopeInheriting Value.WithLet BuiltinScope.scopePrototype) in

    (* Main loop *)
    let rec execute_step stack =
        (* For nonsensical matches *)
        let internalFail () = failwith "Internal consistency error: Reached impossible place" in

        (* Helper: Combine a value with an existing register var to make a new register var. *)
        (* Only call if we know this is not a pair already (unless we *want* to flatten) *)
        let newStateFor register v = match register with
            (* Either throw out a stale LineStart / PairValue and simply take the new value, *)
            | LineStart _ | PairValue _ -> FirstValue (v)
            (* Or combine with an existing value to make a pair. *)
            | FirstValue fv -> PairValue (fv, v)

        (* Look at stack *)
        in match stack with
            (* Asked to execute an empty file -- just return *)
            | [] -> () (* TODO: Remove bails *)

            (* Break stack frames into first and rest *)
            | frame :: moreFrames ->
                (* Trace here ONLY if command line option requests it *)
                if Options.(run.trace) then print_endline @@ "    Step | Depth " ^ (string_of_int @@ stackDepth stack) ^ " | State " ^ (dumpRegisterState frame.register) ^ " | Code " ^ (Pretty.dumpTreeTerse ( Token.makeGroup {Token.fileName=None; Token.lineNumber=0;Token.lineOffset=0} Token.NonClosure Token.Plain frame.code ));

                (* Enter a frame as if returning this value from a function. *)
                let returnTo stackTop v =
                    (* Trace here ONLY if command line option requests it *)
                    if Options.(run.trace) then print_endline @@ "<-- " ^ (dumpPrinter v);

                    (* Unpack the new stack. *)
                    match stackTop with
                        (* It's empty. We're returning from the final frame and can just exit. *)
                        | [] -> ()

                        (* Pull one frame off the stack so we can replace the register var and re-add it. *)
                        | {register=parentRegister; code=parentCode; scope=parentScope} :: pastReturnFrames ->
                            let newState = newStateFor parentRegister v in
                            execute_step @@ { register = newState; code = parentCode; scope = parentScope } :: pastReturnFrames

                (* apply item a to item b and return it to the current frame *)
                in let rec apply onstack a b =
                    let r v = returnTo onstack v in
                    (* Pull something out of a table, possibly recursing *)
                    let readTable t =
                        match Value.tableGet t b with
                            | Some Value.BuiltinMethodValue f -> r @@ Value.BuiltinFunctionValue(f a) (* TODO: This won't work as intended with .parent *)
                            | Some v -> r v
                            | None ->
                                match Value.tableGet t Value.parentKey with
                                    | Some parent -> apply onstack parent b
                                    | None -> failwith ("Key " ^ Pretty.dumpValue(b) ^ " not recognized")
                    in let setTable t =
                        r (Value.tableBoundSet t b)
                    (* Perform the application *)
                    in match a with
                        | Value.ClosureValue c ->
                            let scope = closureScope c in
                                (* Trace here ONLY if command line option requests it *)
                                if Options.(run.trace) then print_endline @@ "Closure --> " ^ dumpPrinter scope;

                                (match scope with
                                    | Value.TableValue t ->
                                        (match c.Value.key with
                                            | Some key ->
                                                Value.tableSet t (Value.AtomValue key) b
                                            | None -> ()
                                        )
                                    | _ -> internalFail())
                                ; execute_step @@ (executeFrame scope c.Value.code)::onstack
                        | Value.TableValue t ->  readTable t
                        (* Basic values *)
                        | Value.Null ->          readTable BuiltinNull.nullPrototypeTable
                        | Value.True ->          readTable BuiltinTrue.truePrototypeTable
                        | Value.FloatValue v ->  readTable BuiltinFloat.floatPrototypeTable
                        | Value.StringValue v -> readTable BuiltinTrue.truePrototypeTable
                        | Value.AtomValue v ->   readTable BuiltinTrue.truePrototypeTable
                        | Value.BuiltinFunctionValue f -> r ( f b )
                        | Value.TableHasValue t -> if (Value.tableHas t b) then r Value.True
                            else (match Value.tableGet t Value.parentKey with
                                (* Have to step one down. FIXME: Unify this with Set implementation? *)
                                | Some parent ->
                                    execute_step @@ (executeFrame (Value.snippetScope ["target",Value.TableValue(t);"key",b]) parentHasSnippet)::stack
                                | None -> r Value.Null)
                        | Value.TableSetValue t -> if (Value.tableHas t b) then setTable t
                            else (match Value.tableGet t Value.parentKey with
                                (* Have to step one down. FIXME: Refactor with instance below? *)
                                | Some parent ->
                                    execute_step @@ (executeFrame (Value.snippetScope ["target",Value.TableValue(t);"key",b]) parentSetSnippet)::stack
                                | None -> failwith ("Key " ^ Pretty.dumpValue(b) ^ " not recognized for set"))
                        | Value.TableLetValue t -> if (not (Value.tableHas t b)) then Value.tableSet t b Value.Null;
                            setTable t
                        (* Unworkable *)
                        | Value.BuiltinMethodValue _ -> internalFail() (* Builtin method values should be erased by readTable *)

                (* Check the state of the top frame *)
                in match frame.register with
                    (* It has two values-- apply before we do anything else *)
                    | PairValue (a, b) ->
                        apply stack a b

                    (* Either no values or just one values, so let's look at the tokens *)
                    | FirstValue _ | LineStart _ ->

                        (* Pop current frame from the stack, integrate the result into the last frame and recurse (TODO) *)

                        (* Look at code sequence in frame *)
                        match frame.code with
                            (* It's empty. We have reached the end of the group. *)
                            | [] -> let value = match frame.register with (* Unpack Value 1 from register *)
                                    | LineStart v | FirstValue v -> v
                                    | _ -> internalFail() (* If PairValue, should have branched off above *)
                                (* "Return from frame" and recurse *)
                                in returnTo moreFrames value

                            (* Break lines in current frame's codeSequence into first and rest *)
                            | line :: moreLines ->

                                (* Look at line in code sequence. *)
                                match line with
                                    (* It's empty. We have reached the end of the line. *)
                                    | [] ->
                                        (* Convert Value 1 to a LineStart value to persist to next line *)
                                        let newState = match frame.register with
                                            | LineStart v | FirstValue v -> LineStart v
                                            | _ -> internalFail() (* Again: if PairValue, should have branched off above *)

                                        (* Replace current frame, new code sequence is rest-of-lines, and recurse *)
                                        in execute_step @@ { register=newState; code=moreLines; scope=frame.scope } :: moreFrames

                                    (* Break tokens in current line into first and rest *)
                                    | token :: moreTokens ->
                                        (* Helper: Given a value, and knowing register state, make a new register state and recurse *)
                                        let stackWithRegister register  =
                                            { register=register; code=moreTokens::moreLines; scope=frame.scope } :: moreFrames

                                        in let simpleValue v =
                                            (* ...new register state... *)
                                            let newState = newStateFor frame.register v
                                            (* Replace current line by replacing current frame, new line is rest-of-line, and recurse *)
                                            in execute_step @@ stackWithRegister newState

                                        in let closureValue v =
                                            let key = match v.Token.closure with Token.ClosureWithBinding b -> Some b | _ -> None in
                                            let scoped = match v.Token.kind with Token.Plain -> true | _ -> false in
                                            simpleValue (Value.ClosureValue { Value.code=v.Token.items; scope=frame.scope; key=key; scoped=scoped; })

                                        (* Evaluate token *)
                                        in match token.Token.contents with
                                            (* Straightforward values that can be evaluated in place *)
                                            | Token.Word s ->   apply (stackWithRegister frame.register) frame.scope (Value.AtomValue s)
                                            | Token.String s -> simpleValue(Value.StringValue s)
                                            | Token.Atom s ->   simpleValue(Value.AtomValue s)
                                            | Token.Number f -> simpleValue(Value.FloatValue f)
                                            | Token.Group group ->
                                                match group.Token.closure with
                                                    (* Token is nontrivial to evaluate, and will require a new stack frame. *)
                                                    | Token.NonClosure -> (* FIXME: Does not properly honor WithLet/NoLet! *)
                                                        let newScope = (groupScope group.Token.kind frame.scope) in
                                                        let items = match group.Token.kind with
                                                            | Token.Box ->
                                                                let wrapperGroup = Token.(makePositionless @@ Group {kind=Plain; closure=NonClosure; items=group.Token.items}) in
                                                                let word = Token.(makePositionless @@ Word Value.currentKeyString) in
                                                                [ [wrapperGroup]; [word] ]
                                                            | _ -> group.Token.items
                                                        in

                                                        (* Trace here ONLY if command line option requests it *)
                                                        if Options.(run.trace) then print_endline @@ "Group --> " ^ dumpPrinter newScope;

                                                        execute_step @@ (executeFrame newScope items)::(stackWithRegister frame.register)
                                                    | _ -> closureValue group

    in match code.Token.contents with
        | Token.Group contents -> execute_step @@ [initialExecuteFrame contents.Token.items]
        | _ -> () (* Execute a constant value-- no effect *)
