(* Shows a friendly banner *)
let doBanner () =
  print_endline("emily v0.1 repl");
  print_endline("%help for help, %quit to quit");
  print_endline("have fun!")

(* Shows a help message *)
let doHelp () =
  print_endline("put a helpful message here")

(* Shows a help message *)
let doUnknownCmd cmd =
  print_string "ERROR: unknown command ";
  print_endline cmd

(* Check if the string 's' starts with 'prefix'. *)
let startsWith s prefix =
  let n = String.length prefix in
  let rec cmp i =
    if i == n then true
    else if (String.get s i) != (String.get prefix i) then false
    else cmp (i + 1) in
  (String.length s) >= n && cmp 0

(* Check if the string 's' ends with 'suffix'. *)
let endsWith s suffix =
  let m = String.length s in
  let n = String.length suffix in
  let rec cmp i j =
    if j == n then true
    else if (String.get s i) != (String.get suffix j) then false
    else cmp (i + 1) (j + 1) in
  m >= n && cmp (m - n) 0

(* Check if the string 's' starts with a tab or space. *)
let isIndented s =
  if (String.length s) == 0 then false
  else let c = (String.get s 0) in c == '\t' || c == ' '

(* Check if the string 's' ends with a backslash. *)
let isContinued s =
  endsWith s "\\"

(* Check if the string 's' starts with %. *)
let isMetaCommand s =
  startsWith s "%"

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

  let runUserFiles () =
    List.iter runTargetFiles targets in

  (* the user entered a meta command -- handle it! *)
  let handleMetaCommand cmd =
    match cmd with
    | "%quit" -> raise End_of_file
    | "%help" -> doHelp ()
    | _ -> doUnknownCmd cmd in

  (* the user is entering code -- read it all and then run it *)
  let handleCode () =
    (* keep reading lines if continued with \ *)
    while (isContinued !line) do promptAndReadLine "..> " done;

    (* now run the accumulated lines *)
    runInput ();

    (* flush stdout so any output is immediately visible *)
    flush stdout in

  doBanner ();

  (* next, run any files provided as arguments *)
  runUserFiles ();

  try
    (* as long as the user hasn't sent EOF (Control-D), read input *)
    while true do

      (* draw a prompt, and read one line of input *)
      promptAndReadLine ">>> ";

      (* handle the user's input appropriately *)
      if (isMetaCommand !line) then handleMetaCommand !line else handleCode ();

      (* empty lines, since they have all been executed *)
      lines := [];
    done;

  with End_of_file ->
    print_endline "bye!"
