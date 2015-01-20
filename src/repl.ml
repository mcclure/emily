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
  let scope = Execute.scopeInheriting Value.WithLet BuiltinScope.scopePrototype in
  let line = ref "" in
  let lines = ref [] in

  let runCode code =
    (match code.Token.contents with
     | Token.Group contents ->
        let frame = Execute.executeNext scope contents.Token.items code.Token.at in
        Execute.executeStep @@ [frame]
     | _ -> ()) in

  let runFile f =
    runCode (Tokenize.tokenize_channel (Token.File f) (open_in f)) in

  let runTarget t =
    match t with
      | Options.File f -> runFile f
      | _ -> () in

  List.iter runTarget targets;

  try
      while true do
        line := input_line stdin;
        lines := !line :: !lines;
        while (isContinued !line) do
          line := input_line stdin;
          lines := !line :: !lines;
        done;
    
        let xdata = (String.concat "\n" (List.rev !lines)) in
        let code = (Tokenize.tokenize_string Token.Cmdline xdata) in

        (match code.Token.contents with
          | Token.Group contents ->
             let frame = Execute.executeNext scope contents.Token.items code.Token.at in
             Execute.executeStep @@ [frame]
          | _ -> ()
        );

        flush stdout;
        lines := [];
      done;
    with End_of_file ->
      print_string "bye!\n"
