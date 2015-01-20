(* Return true if string starts with a tab or space, false otherwise. *)
let isIndented s =
  if (String.length s) == 0 then false
  else match (String.get s 0) with
       | '\t' -> true
       | ' ' -> true
       | _ -> false

(* Return true if string starts with a backslash, false otherwise. *)
let isContinued s =
  let len = String.length s in
  if len == 0 then false else (String.get s (len - 1)) == '\\'

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

  (* read a line of user input *)
  let readInputLine =
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

  (* run all lines of user input *)
  let runInput lines =
    let data = String.concat "\n" (List.rev !lines) in
    runCode (Tokenize.tokenize_string Token.Cmdline data) in

  (* first, run any files provided as arguments *)
  List.iter runTargetFiles targets;

  try
    (* as long as the user hasn't sent EOF (Control-D), read input *)
    while true do
      (* read one line of input *)
      readInputLine;

      (* as long as the line is continued, keep accumulating input *)
      while (isContinued !line) do readInputLine done;

      (* now run the accumulated lines *)
      runInput lines;

      (* flush stdout so any output is immediately visible *)
      flush stdout;

      (* empty lines, since they have all been executed *)
      lines := [];
    done;

  with End_of_file ->
    print_endline "bye!"
