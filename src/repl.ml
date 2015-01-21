(* predefined Emily code used by the REPL *)
let emilyReplFunctions = "
help = ^( println \"put a helpful message here\" )
quit = ^( println \"quit() called\" )

println \"emily v0.1 repl\"
println \"help() for help, quit() to quit\"
println \"have fun!\"
"

(* Check if the string 's' ends with a backslash. *)
let isContinued s =
  let n = String.length s in
  n > 0 && (String.get s (n - 1)) == '\\'

(* Runs the REPL.

This is the high-level method that Main uses to run the REPL.
It needs to set up a global scope to use, then execute the
files provided as arguments (if any) and then start reading
input from the user.

Right now, the REPL doesn't produce any output itself, so
users must use functions like "println" to inspect values
and see the result of function calls.

Control-D (EOF) exits the REPL.

*)
let repl targets =

  (* this is our global mutable REPL scope *)
  let scope = Execute.scopeInheriting Value.WithLet BuiltinScope.scopePrototype in

  (* line and lines are used to read and execute user input *)
  let line = ref "" in
  let lines = ref [] in

  (* display a prompt, then read a line from the user *)
  let promptAndReadLine s =
    print_string s;
    flush stdout;
    line := input_line stdin;
    lines := !line :: !lines in

  (* run the provided tokenized code *)
  let runCode code =
    (match code.Token.contents with
     | Token.Group contents ->
        let frame = Execute.executeNext scope contents.Token.items code.Token.at in
        Execute.executeStep @@ [frame]
     | _ -> ()) in

  (* tokenize and execute the given file target *)
  let runFile f =
    runCode (Tokenize.tokenize_channel (Token.File f) (open_in f)) in

  (* run all file targets -- skip all other targets *)
  let runTargetFiles t =
    match t with
      | Options.File f -> runFile f
      | _ -> () in

  (* run the given string *)
  let runString data =
    runCode (Tokenize.tokenize_string Token.Cmdline data) in

  (* run all lines of user input *)
  let runInput () =
    runString (String.concat "\n" (List.rev !lines)) in

  let runEmilyReplFunctions () =
    runString emilyReplFunctions in

  let runUserFiles () =
    List.iter runTargetFiles targets in

  (* the user is entering code -- read it all and then run it *)
  let handleCode () =
    (* keep reading lines if continued with \ *)
    while (isContinued !line) do promptAndReadLine "..> " done;

    (* now run the accumulated lines *)
    try
      runInput ()
    with Failure e ->
      print_endline e;

    (* flush stdout so any output is immediately visible *)
    flush stdout in

  (* first, run emily's built-in repl functions *)
  runEmilyReplFunctions ();

  (* next, run any files provided as arguments *)
  runUserFiles ();

  Sys.catch_break true;

  try
    (* as long as the user hasn't sent EOF (Control-D), read input *)
    while true do
      (try
        (* draw a prompt, and read one line of input *)
        promptAndReadLine ">>> ";

        (* handle the user's input appropriately *)
        match !line with
        | "quit()" -> raise End_of_file (* temporary hack *)
        | _ -> handleCode ();

      with Sys.Break ->
        (* control-C should clear the line, draw a new prompt *)
        print_endline "";
        lines := []);

      (* empty lines, since they have all been executed *)
      lines := [];
    done;

  with End_of_file ->
    (* time to exit the REPL *)
    print_endline "bye!"
