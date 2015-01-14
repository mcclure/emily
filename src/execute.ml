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

(* -- DEBUG / PRETTYPRINT HELPERS -- *)

(* Pretty print for registerState. Can't go in Pretty.ml because module recursion. *)
let dumpRegisterState registerState =
    match registerState with
    | Value.LineStart (v,_) -> "LineStart:" ^ (Pretty.dumpValue v)
    | Value.FirstValue (v,_,_) -> "FirstValue:" ^ (Pretty.dumpValue v)
    | Value.PairValue (v1,v2,_,_) -> "PairValue:" ^ (Pretty.dumpValue v1) ^ "," ^ (Pretty.dumpValue v2)

(* FIXME: I wonder if there's a existing function for this in List or something. *)
let stackDepth stack =
    let rec stackDepthImpl accum stack =
        match stack with
            | [] -> accum
            | _::more -> stackDepthImpl (accum+1) more
    in stackDepthImpl 0 stack

(* -- PRACTICAL HELPERS -- *)

type anchoredValue = Value.value * Token.codePosition

(* These three could technically move into value.ml but BuiltinObject depends on Value *)
let scopeInheriting kind v =
    Value.TableValue(ValueUtil.tableInheriting kind v)
let objectInheriting kind v = (* is this needed? *)
    Value.ObjectValue(ValueUtil.tableInheriting kind v)

(* Given a parent scope and a token creates an appropriate inner group scope *)
let groupScope tokenKind scope =
    match tokenKind with
        | Token.Plain  -> scope
        | Token.Scoped -> scopeInheriting Value.WithLet scope
        | Token.Box    -> objectInheriting (Value.BoxFrom (Some BuiltinObject.objectPrototype)) scope

(* Combine a value with an existing register var to make a new register var. *)
(* Flattens pairs, on the assumption if a pair is present we're returning their applied value, *)
(* so only call if we know this is not a pair already (unless we *want* to flatten) *)
let newStateFor register av = match register,av with
    (* Either throw out a stale LineStart / PairValue and simply take the new value, *)
    | Value.LineStart (_,rat),(v,at) | Value.PairValue (_,_,rat,_),(v,at) -> Value.FirstValue (v, rat, at)
    (* Or combine with an existing value to make a pair. *)
    | Value.FirstValue (v,rat,_),(v2,at) -> Value.PairValue (v, v2, rat, at)

(* Constructor for a new frame *)
let executeNext scope code at = Value.{register=LineStart(Value.Null,at); code; scope}

(* Only call if it really is impossible, since this gives no debug feedback *)
(* Mostly I call this if a nested match has to implement a case already excluded *)
let internalFail () = failwith "Internal consistency error: Reached impossible place"

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

(* TCO notes:
    These are the recursion points for executeStep:
        evaluateTokenFromLines -> Line is present, but empty -> move to next
        returnTo -> top frame exists, a value was calculated by an outer frame, combine down onto it
        evaluateTokenFromTokens.simpleValue -> new value for this current frame known, just set it
        evaluateTokenFromTokens -> DESCENT: next token is a group; evaluate it.
        apply -> DESCENT: application is closure to value; make stack frame.
        apply -> DESCENT: application is hasValue or setValue; do in lower stack frame.
    In future, it might be useful to do the TCO stack rewriting at the descent points and
    blank-line removal at tokenize time, instead of wasting time on it each loop start.
*)

(* These first five functions are mostly routing: *)
(* executeStep is the "start of the loop"-- the entry point we return to after each action.
   it currently just unpacks the stack, cleans it up, and passes components on to process. *)
let rec executeStep stack =
    match stack with
        (* Unusual edge case: Asked to execute an empty file -- just return *)
        | [] -> ()

        (* Here some tail call optimization passes occur. We check for special stack patterns
           implying unnecessary space on the stack, then rewrite the stack to avoid them. *)

        (* Case #1: Remove blank lines so they don't mess up other TCO checks later *)
        | {Value.register; Value.scope; Value.code=line::[]::rest}::moreFrames ->
            executeStep @@ Value.{register; scope; code=line::rest}::moreFrames

        (* Case #2: A normal group descent, but into an unnecessary pair of parenthesis.
           IOW, the next-to-top frame does no work; its code only ever contained a group token. *)
        | frame :: {Value.register=Value.LineStart _; Value.code=[[]]} :: moreFrames ->
            executeStep @@ frame::moreFrames

        (* Case #3: Canonical tail call: A function application, at the end of a group.
           We can thus excise the frame that's just waiting for the application to return. *)
        | frame :: {Value.register=Value.PairValue _; Value.code=[[]]} :: moreFrames ->
            executeStep @@ frame::moreFrames

        (* Case #4: Applying a continuation: We can ditch all other context. *)
        | {Value.register=Value.FirstValue (Value.ContinuationValue (continueStack,at),_,_);
           Value.code = (_::_)::_ (* "Match a nonempty two-dimensional list" *)
          } as frame :: moreFrames ->
            executeStep @@ Value.{frame with register=LineStart(Null, at)}::continueStack

        (* Break stack frames into first and rest *)
        | frame :: moreFrames ->
            executeStepWithFrames stack frame moreFrames

and executeStepWithFrames stack frame moreFrames =
    (* Trace here ONLY if command line option requests it *)
    if Options.(run.trace) then print_endline @@ "    Step | Depth " ^ (string_of_int @@ stackDepth stack) ^ (if Options.(run.trackObjects) then " | Scope " ^ Pretty.dumpValue(frame.Value.scope) else "") ^ " | State " ^ (dumpRegisterState frame.Value.register) ^ " | Code " ^ (Pretty.dumpCodeTreeTerse ( Token.makeGroup {Token.fileName=Token.Unknown; Token.lineNumber=0;Token.lineOffset=0} Token.NonClosure Token.Plain frame.Value.code ));

    (* Check the state of the top frame *)
    match frame.Value.register with
        (* It has two values-- apply before we do anything else *)
        | Value.PairValue (a, b, rat, bat) ->
            apply stack a a (b,bat)

        (* Either no values or just one values, so let's look at the tokens *)
        | Value.FirstValue _ | Value.LineStart _ ->
            evaluateToken stack frame moreFrames
            (* Pop current frame from the stack, integrate the result into the last frame and recurse (TODO) *)

and evaluateToken stack frame moreFrames =
    (* Look at code sequence in frame *)
    match frame.Value.code with
        (* It's empty. We have reached the end of the group. *)
        | [] -> let avalue = match frame.Value.register with (* Unpack Value 1 from register *)
                | Value.LineStart (v,rat) | Value.FirstValue (v,rat,_) -> (v,rat)
                | _ -> internalFail() (* If PairValue, should have branched off above *)
            (* "Return from frame" and recurse *)
            in returnTo moreFrames avalue

        (* Break lines in current frame's codeSequence into first and rest *)
        | line :: moreLines ->
            evaluateTokenFromLines stack frame moreFrames line moreLines

and evaluateTokenFromLines stack frame moreFrames line moreLines =
    (* Look at line in code sequence. *)
    match line with
        (* It's empty. We have reached the end of the line. *)
        | [] ->
            (* Convert Value 1 to a LineStart value to persist to next line *)
            let newState = match frame.Value.register with
                | Value.LineStart (v,rat) | Value.FirstValue (v,rat,_) -> Value.LineStart (v,rat)
                | _ -> internalFail() (* Again: if PairValue, should have branched off above *)

            (* Replace current frame, new code sequence is rest-of-lines, and recurse *)
            in executeStep @@ Value.{ register=newState; code=moreLines; scope=frame.scope } :: moreFrames

        (* Break tokens in current line into first and rest *)
        | token :: moreTokens ->
            evaluateTokenFromTokens stack frame moreFrames line moreLines token moreTokens

(* Enter a frame as if returning this value from a function. *)
and returnTo stackTop av =
    (* Trace here ONLY if command line option requests it *)
    if Options.(run.trace) then print_endline @@ "<-- " ^ (let v,_ = av in Pretty.dumpValue v);

    (* Unpack the new stack. *)
    match stackTop with
        (* It's empty. We're returning from the final frame and can just exit. *)
        | [] -> ()

        (* Pull one frame off the stack so we can replace the register var and re-add it. *)
        | {Value.register=parentRegister; Value.code=parentCode; Value.scope=parentScope} :: pastReturnFrames ->
            let newState = newStateFor parentRegister av in
            executeStep @@ Value.{ register = newState; code = parentCode; scope = parentScope } :: pastReturnFrames

(* evaluateTokenFromTokens and apply are the functions that "do things"-- they
   define, ultimately, the meanings of the different kinds of tokens and values. *)

and evaluateTokenFromTokens stack frame moreFrames line moreLines token moreTokens =
    (* Helper: Given a value, and knowing register state, make a new register state and recurse *)
    let stackWithRegister register  =
        Value.{ register; code=moreTokens::moreLines; scope=frame.scope } :: moreFrames

    in let simpleValue v =
        (* ...new register state... *)
        let newState = newStateFor frame.Value.register (v,token.Token.at)
        (* Replace current line by replacing current frame, new line is rest-of-line, and recurse *)
        in executeStep @@ stackWithRegister newState

    in let closureValue v =
        let return,key = match v.Token.closure with Token.ClosureWithBinding(r,k) -> r,k | _ -> internalFail() in
        let scoped = match v.Token.kind with Token.Scoped -> true | _ -> false in
        simpleValue Value.(ClosureValue { exec=ClosureExecUser {body=v.Token.items; envScope=frame.scope; key; scoped; return; }; bound=[]; this=Value.ThisBlank; needArgs=(List.length key) })

    (* Identify token *)
    in match token.Token.contents with
        (* Straightforward values that can be evaluated in place *)
        | Token.Word s ->   apply (stackWithRegister frame.Value.register) frame.Value.scope frame.Value.scope (Value.AtomValue s, token.Token.at)
        | Token.String s -> simpleValue(Value.StringValue s)
        | Token.Atom s ->   simpleValue(Value.AtomValue s)
        | Token.Number f -> simpleValue(Value.FloatValue f)
        | Token.Symbol s -> Token.failToken token @@ "Faulty macro: Symbol "^s^" left unprocessed"
        (* Not straightforward. *)
        | Token.Group group ->
            match group.Token.closure with
                (* Token is nontrivial to evaluate, and will require a new stack frame. *)
                | Token.NonClosure -> (* FIXME: Does not properly honor WithLet/NoLet! *)
                    let newScope = (groupScope group.Token.kind frame.Value.scope) in
                    let items = match group.Token.kind with
                        | Token.Box ->
                            let wrapperGroup = Token.(clone token @@ Group {kind=Plain; closure=NonClosure; items=group.Token.items}) in
                            let word = Token.(clone token @@ Word Value.currentKeyString) in
                            [ [wrapperGroup]; [word] ]
                        | _ -> group.Token.items
                    in

                    (* Trace here ONLY if command line option requests it *)
                    if Options.(run.trace) then print_endline @@ "Group --> " ^ Pretty.dumpValueNewTable newScope;

                    (* New frame: Group descent *)
                    executeStep @@ (executeNext newScope items token.Token.at)::(stackWithRegister frame.Value.register)
                | _ -> closureValue group

(* apply item a to item b and return it to the current frame *)
and apply stack this a b =
    let bv,bat = b in
    let r v = returnTo stack (v,bat) in
    (* Pull something out of a table, possibly recursing *)
    let readTable t =
        match (a,Value.tableGet t bv) with
                | _, Some Value.BuiltinMethodValue      f -> r @@ Value.BuiltinFunctionValue(f this)
                | _, Some Value.BuiltinUnaryMethodValue f -> r @@ f this
                | Value.ObjectValue _, Some (Value.ClosureValue _ as c) -> r @@ ValueUtil.rawRethisSuperFrom this c
                | _, Some v -> r v
                | _, None ->
                    match a,Value.tableGet t Value.parentKey with
                        | Value.ObjectValue _, Some (Value.ClosureValue _ as parent) ->
                            apply stack this (ValueUtil.rawRethisSuperFrom this parent) b
                        | _,Some parent -> apply stack this parent b
                        | _,None -> ValueUtil.rawMisapplyStack stack this bv
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
                        let scope = scopeInheriting scopeKind exec.Value.envScope in
                        let key = exec.Value.key in (
                            (* Trace here ONLY if command line option requests it *)
                            if Options.(run.trace) then print_endline @@ "Closure --> " ^ Pretty.dumpValueNewTable scope;

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
                                        Value.tableSet t Value.superKey (ValueUtil.makeSuper current this) in
                                    match c.Value.this with
                                        | Value.CurrentThis(c,t) | Value.FrozenThis(c,t)
                                            -> setThis c t
                                        | _ -> ());
                                    (match c.Value.exec with
                                        | Value.ClosureExecUser({Value.return=true}) ->
                                            Value.tableSet t Value.returnKey (Value.ContinuationValue (stack,bat))
                                        | _ -> ());
                                    addBound key bound
                                | _ -> internalFail()
                        );
                        executeStep @@ (executeNext scope exec.Value.body bat)::stack
                | Value.ClosureExecBuiltin f ->
                    r (f bound)
            in (match c.Value.needArgs with
                | 0 -> descend c (* Apply discarding argument *)
                | count ->
                    let amendedClosure = Value.{ c with needArgs=count-1;
                        bound=bv::c.bound } in (* b b is nonsense! *)
                    match count with
                        | 1 -> descend amendedClosure (* Apply, using argument *)
                        | _ -> r (Value.ClosureValue amendedClosure) (* Simply curry and return. Don't descend stack. *)
            )

        | Value.ContinuationValue (stack,_) -> (* FIXME: Won't this be optimized out? *)
            returnTo stack b

        (* If applying a table or table op. *)
        | Value.ObjectValue t  | Value.TableValue t ->  readTable t
        (* If applying a primitive value. *)
        | Value.Null ->          readTable BuiltinNull.nullPrototypeTable
        | Value.True ->          readTable BuiltinTrue.truePrototypeTable
        | Value.FloatValue v ->  readTable BuiltinFloat.floatPrototypeTable
        | Value.StringValue v -> readTable BuiltinTrue.truePrototypeTable
        | Value.AtomValue v ->   readTable BuiltinTrue.truePrototypeTable
        (* If applying a builtin special. *)
        | Value.BuiltinFunctionValue f -> r ( f bv )
        (* Unworkable -- all builtin method values should be erased by readTable *)
        | Value.BuiltinMethodValue _ | Value.BuiltinUnaryMethodValue _
            -> internalFail()

(* --- MAIN LOOP ENTRY POINT --- *)

(* Execute and return nothing. *)
let execute code =
    match code.Token.contents with
    | Token.Group contents ->
        (* Make a new blank frame with the given code sequence and an empty scope, *)
        let initialScope = scopeInheriting Value.WithLet BuiltinScope.scopePrototype in
        let initialFrame = executeNext initialScope contents.Token.items code.Token.at
        in executeStep @@ [initialFrame] (* then place it as the start of the stack. *)
    | _ -> () (* Execute a constant value-- no effect *)
