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

(* -- TYPES -- *)

(* We imagine values 1 and 2 as "registers"... *)
type registerState =
    | LineStart of Value.value
    | FirstValue of Value.value
    | PairValue of (Value.value * Value.value)

(* Each frame on the stack has the two value "registers" and a codeSequence reference which
   is effectively an instruction pointer. *)
type executeFrame = {
    register : registerState;
    code : Token.codeSequence;
    scope: Value.value;
}

(* The current state of an execution thread consists of just the stack of frames. (Is there gonna be more here later?) *)
and executeState = executeFrame list

(* -- DEBUG / PRETTYPRINT HELPERS -- *)

(* Pretty print for registerState. Can't go in Pretty.ml because module recursion. *)
let dumpRegisterState registerState =
    match registerState with
    | LineStart v -> "LineStart:" ^ (Pretty.dumpValue v)
    | FirstValue v -> "FirstValue:" ^ (Pretty.dumpValue v)
    | PairValue (v1,v2) -> "PairValue:" ^ (Pretty.dumpValue v1) ^ "," ^ (Pretty.dumpValue v2)

(* FIXME: I wonder if there's a existing function for this in List or something. *)
let stackDepth stack =
    let rec stackDepthImpl accum stack =
        match stack with
            | [] -> accum
            | _::more -> stackDepthImpl (accum+1) more
    in stackDepthImpl 0 stack

(* -- PRACTICAL HELPERS -- *)

(* These three could technically move into value.ml but BuiltinObject depends on Value *)
let scopeInheriting kind v =
    Value.TableValue(Value.tableInheriting kind v)

(* Given a parent scope and a token creates an appropriate inner group scope *)
let groupScope tokenKind scope =
    match tokenKind with
        | Token.Plain  -> scope
        | Token.Scoped -> scopeInheriting Value.WithLet scope
        | Token.Box    -> scopeInheriting (Value.BoxFrom (Some BuiltinObject.objectPrototype)) scope

(* Combine a value with an existing register var to make a new register var. *)
(* Flattens pairs, on the assumption if a pair is present we're returning their applied value, *)
(* so only call if we know this is not a pair already (unless we *want* to flatten) *)
let newStateFor register v = match register with
    (* Either throw out a stale LineStart / PairValue and simply take the new value, *)
    | LineStart _ | PairValue _ -> FirstValue (v)
    (* Or combine with an existing value to make a pair. *)
    | FirstValue fv -> PairValue (fv, v)

(* THIS-FIXME: This is no good because it will not take into account binding changes after the set is captured. *)
let tableBoundSet t key =
    let f value =
        if Options.(run.traceSet) then print_endline @@ "        SET: " ^ (Pretty.dumpValue key) ^ " = " ^ (Pretty.dumpValue value);
        Value.tableSet t key value; Value.Null
    in Value.BuiltinFunctionValue(f)
let tableBoundHas t key =
    let f value =
        Value.boolCast( Value.tableHas t key )
    in Value.BuiltinFunctionValue(f)

(* Constructor for a new frame *)
let executeFrame scope code = {register=LineStart(Value.Null); code=code; scope=scope}

(* Only call if it really is impossible, since this gives no debug feedback *)
(* Mostly I call this if a nested match has to implement a case already excluded *)
let internalFail () = failwith "Internal consistency error: Reached impossible place"

(* -- SNIPPETS (inlined Emily code) -- *)

let parentSetSnippet = Tokenize.snippet "target.parent.set key"
let parentHasSnippet = Tokenize.snippet "target.parent.has key"

(* -- INTERPRETER MAIN LOOP -- *)

(* A tree of mutually recursive functions:

executeStep: ("Proceed")
    | EXIT (Rare-- when entire program is empty)
    \ executeStepWithFrames: ("Evaluate first frame in stack")
        | apply (When register contains pair)
        \ evaluateToken: (When no pair, and we should check next token)
            | returnTo (When no token lines)
            \ evaluateTokenFromLines: ("Check first line of code after instruction pointer")
                | executeStep (When first line is empty)
                \ evaluateTokenFromTokens: ("Check first token in first line")
                    | apply (when evaluating word)
                    \ executeStep (when token evaluated and stack frame is adjusted with new register and/or new additional frame.)

returnTo: (A value has been calculated and a new stack top decided on; fit that value into the stack top's register.)
    | EXIT (when return from final frame)
    \ executeStep (to proceed with new register)

apply: (A pair of values has been identified; evaluate their application.)
    | returnTo (when application result can be calculated immediately)
    \ executeStep (when a closure or snippet requires a new frame)

*)

(* These first five functions are mostly routing: *)
let rec executeStep stack = (* Unpack stack *)
    match stack with
        (* Asked to execute an empty file -- just return *)
        | [] -> ()

        (* Break stack frames into first and rest *)
        | frame :: moreFrames ->
            executeStepWithFrames stack frame moreFrames

and executeStepWithFrames stack frame moreFrames =
    (* Trace here ONLY if command line option requests it *)
    if Options.(run.trace) then print_endline @@ "    Step | Depth " ^ (string_of_int @@ stackDepth stack) ^ " | State " ^ (dumpRegisterState frame.register) ^ " | Code " ^ (Pretty.dumpCodeTreeTerse ( Token.makeGroup {Token.fileName=None; Token.lineNumber=0;Token.lineOffset=0} Token.NonClosure Token.Plain frame.code ));

    (* Check the state of the top frame *)
    match frame.register with
        (* It has two values-- apply before we do anything else *)
        | PairValue (a, b) ->
            apply stack a a b

        (* Either no values or just one values, so let's look at the tokens *)
        | FirstValue _ | LineStart _ ->
            evaluateToken stack frame moreFrames
            (* Pop current frame from the stack, integrate the result into the last frame and recurse (TODO) *)

and evaluateToken stack frame moreFrames =
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
            evaluateTokenFromLines stack frame moreFrames line moreLines

and evaluateTokenFromLines stack frame moreFrames line moreLines =
    (* Look at line in code sequence. *)
    match line with
        (* It's empty. We have reached the end of the line. *)
        | [] ->
            (* Convert Value 1 to a LineStart value to persist to next line *)
            let newState = match frame.register with
                | LineStart v | FirstValue v -> LineStart v
                | _ -> internalFail() (* Again: if PairValue, should have branched off above *)

            (* Replace current frame, new code sequence is rest-of-lines, and recurse *)
            in executeStep @@ { register=newState; code=moreLines; scope=frame.scope } :: moreFrames

        (* Break tokens in current line into first and rest *)
        | token :: moreTokens ->
            evaluateTokenFromTokens stack frame moreFrames line moreLines token moreTokens

(* Enter a frame as if returning this value from a function. *)
and returnTo stackTop v =
    (* Trace here ONLY if command line option requests it *)
    if Options.(run.trace) then print_endline @@ "<-- " ^ (Pretty.dumpValue v);

    (* Unpack the new stack. *)
    match stackTop with
        (* It's empty. We're returning from the final frame and can just exit. *)
        | [] -> ()

        (* Pull one frame off the stack so we can replace the register var and re-add it. *)
        | {register=parentRegister; code=parentCode; scope=parentScope} :: pastReturnFrames ->
            let newState = newStateFor parentRegister v in
            executeStep @@ { register = newState; code = parentCode; scope = parentScope } :: pastReturnFrames

(* evaluateTokenFromTokens and apply are the functions that "do things"-- they
   define, ultimately, the meanings of the different kinds of tokens and values. *)

and evaluateTokenFromTokens stack frame moreFrames line moreLines token moreTokens =
    (* Helper: Given a value, and knowing register state, make a new register state and recurse *)
    let stackWithRegister register  =
        { register=register; code=moreTokens::moreLines; scope=frame.scope } :: moreFrames

    in let simpleValue v =
        (* ...new register state... *)
        let newState = newStateFor frame.register v
        (* Replace current line by replacing current frame, new line is rest-of-line, and recurse *)
        in executeStep @@ stackWithRegister newState

    in let closureValue v =
        let key = match v.Token.closure with Token.ClosureWithBinding b -> b | _ -> internalFail() in
        let scoped = match v.Token.kind with Token.Plain -> true | _ -> false in
        simpleValue Value.(ClosureValue { exec=ClosureExecUser {code=v.Token.items; scope=frame.scope; key=key; scoped=scoped;}; bound=[]; this=Value.Blank; needArgs=(List.length key); needThis=true;
         })

    (* Identify token *)
    in match token.Token.contents with
        (* Straightforward values that can be evaluated in place *)
        | Token.Word s ->   apply (stackWithRegister frame.register) frame.scope frame.scope (Value.AtomValue s)
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
                    if Options.(run.trace) then print_endline @@ "Group --> " ^ Pretty.dumpValue newScope;

                    executeStep @@ (executeFrame newScope items)::(stackWithRegister frame.register)
                | _ -> closureValue group

(* apply item a to item b and return it to the current frame *)
and apply stack this a b =
    let r v = returnTo stack v in
    (* Pull something out of a table, possibly recursing *)
    let readTable t =
        match Value.tableGet t b with
            | Some Value.BuiltinMethodValue f -> r @@ Value.BuiltinFunctionValue(f a) (* TODO: This won't work as intended with .parent *)
            | Some Value.ClosureValue c -> r @@ Value.ClosureValue( Value.rethis this c )
            | Some v -> r v
            | None ->
                match Value.tableGet t Value.parentKey with
                    | Some parent -> apply stack this parent b
                    | None -> failwith ("Key " ^ Pretty.dumpValue(b) ^ " not recognized")
    in let setTable t = (* THIS-FIXME *)
        r (tableBoundSet t b)
    (* Perform the application *)
    in match a with
        (* If applying a closure. *)
        | Value.ClosureValue c ->
            let descend c =
                let bound = List.rev c.Value.bound in
                match c.Value.exec with
                    | Value.ClosureExecUser exec ->
                        (* FIXME: should be a noscope operation for bound=[], this=None *)
                        let scopeKind = if exec.Value.scoped then Value.WithLet else Value.NoLet in
                        let scope = scopeInheriting scopeKind exec.Value.scope in
                        let key = List.rev exec.Value.key in (
                            (* Trace here ONLY if command line option requests it *)
                            if Options.(run.trace) then print_endline @@ "Closure --> " ^ Pretty.dumpValue scope;

                            match scope with
                                | Value.TableValue t ->
                                    let rec addBound keys values = match (keys, values) with
                                        | ([], []) -> ()
                                        | (key::restKey, value::restValue) -> (
                                            Value.tableSet t (Value.AtomValue key) value;
                                            addBound restKey restValue)
                                        | _ -> internalFail() in
                                    (let setThis current this =
                                        Value.tableSet t Value.currentKey current;
                                        Value.tableSet t Value.thisKey this;
                                        Value.tableSet t Value.superKey (BuiltinScope.makeSuper current this) in
                                    match c.Value.this with
                                        | Value.Current c -> setThis c c
                                        | Value.CurrentThis(c,t) -> setThis c t
                                        | _ -> ());
                                    addBound key bound
                                | _ -> internalFail()
                        );
                        executeStep @@ (executeFrame scope exec.Value.code)::stack
                | Value.ClosureExecBuiltin f ->
                    r (f bound)
            in (match c.Value.needArgs with
                | 0 -> descend c (* Apply discarding argument *)
                | count ->
                    let amendedClosure = Value.{ c with needArgs=count-1; bound=b::c.bound } in
                        match count with
                            | 1 -> descend amendedClosure (* Apply, using argument *)
                            | _ -> r (Value.ClosureValue amendedClosure) (* Simply curry and return. Don't descend stack. *)
            )

        (* If applying a table or table op. *)
        | Value.TableValue t ->  readTable t
        (* THIS-FIXME *)
        | Value.TableHasValue t -> if (Value.tableHas t b) then r Value.True
            else (match Value.tableGet t Value.parentKey with
                (* Have to step one down. FIXME: Unify this with Set implementation? *)
                | Some parent ->
                    executeStep @@ (executeFrame (Value.snippetScope ["target",Value.TableValue(t);"key",b]) parentHasSnippet)::stack
                | None -> r Value.Null)
        | Value.TableSetValue t -> if (Value.tableHas t b) then setTable t
            else (match Value.tableGet t Value.parentKey with
                (* Have to step one down. FIXME: Refactor with instance below? *)
                | Some parent ->
                    executeStep @@ (executeFrame (Value.snippetScope ["target",Value.TableValue(t);"key",b]) parentSetSnippet)::stack
                | None -> failwith ("Key " ^ Pretty.dumpValue(b) ^ " not recognized for set"))
        | Value.TableLetValue t -> if (not (Value.tableHas t b)) then Value.tableSet t b Value.Null;
            setTable t
        (* If applying a primitive value. *)
        | Value.Null ->          readTable BuiltinNull.nullPrototypeTable
        | Value.True ->          readTable BuiltinTrue.truePrototypeTable
        | Value.FloatValue v ->  readTable BuiltinFloat.floatPrototypeTable
        | Value.StringValue v -> readTable BuiltinTrue.truePrototypeTable
        | Value.AtomValue v ->   readTable BuiltinTrue.truePrototypeTable
        (* If applying a builtin special. *)
        | Value.BuiltinFunctionValue f -> r ( f b )
        (* Unworkable -- all builtin method values should be erased by readTable *)
        | Value.BuiltinMethodValue _ -> internalFail()

(* --- MAIN LOOP ENTRY POINT --- *)

(* Execute and return nothing. *)
let execute code =
    match code.Token.contents with
    | Token.Group contents ->
        (* Make a new blank frame with the given code sequence and an empty scope, *)
        let initialScope = scopeInheriting Value.WithLet BuiltinScope.scopePrototype in
        let initialFrame = executeFrame initialScope contents.Token.items
        in executeStep @@ [initialFrame] (* then place it as the start of the stack. *)
    | _ -> () (* Execute a constant value-- no effect *)
