(* This file contains an routine that runs an emily repl off stdin. Once entered, it runs until quit. *)
(* In future, this could possibly be moved into its own standalone executable. *)

(* Predefined Emily code used by the REPL *)
let replHelpString = Options.fullVersion^{|, interactive mode
Type "help" for help, "quit" to quit|}

(* Check if the string 's' ends with a backslash. *)
(* FIXME: This is inadequate, the tokenizer should report this itself. *)
let isContinued s =
    let n = String.length s in
    n > 0 && (String.get s (n - 1)) == '\\'

(* Runs the REPL.

This is the high-level entry point that Main uses to run the REPL.
It needs to set up a global scope to use, then execute the
files provided as arguments (if any) and then start reading
input from the user.

Control-D (EOF) exits the REPL, as does evaluating the word `quit`. *)

let repl targets =

    (* This is our global mutable REPL scope *)
    let scope = (
        let project = Loader.loadLocation Loader.Cwd in
        let table = Loader.tableWithLoaders (Some Loader.packageRepo) (Some project) (Some project) in
        (* This function will be run if the user evaluates the symbol `help` *)
        Value.tableSetString table "help" (Value.BuiltinUnaryMethodValue (fun _ ->
            print_endline replHelpString;
            raise Sys.Break (* Stop executing code. Is this too aggressive? *)
        ));
        (* This function will be run if the user evaluates the symbol `quit` *)
        Value.tableSetString table "quit" (Value.BuiltinUnaryMethodValue (fun _ ->
            raise End_of_file (* ANY attempt to read the "quit" variable quits immediately *)
        ));
        Value.TableValue table
    ) in

    (* Line and lines are used to read and execute user input *)
    let line = ref "" in
    let lines = ref [] in

    (* Display a prompt, then read a line from the user *)
    let promptAndReadLine s =
        print_string s;
        flush stdout;
        line := input_line stdin;
        lines := !line :: !lines in

    (* Tokenize and execute the given file target *)
    let runFile f =
        let buf = (Tokenize.tokenizeChannel (Token.File f) (open_in f)) in
        Execute.execute scope buf in

    (* Run all file targets -- skip all other targets *)
    let runTargetFiles t =
        match t with
        | Options.File f -> ignore @@ runFile f
        | _ -> () in

    (* Run the given string *)
    let runString data =
        let buf = Tokenize.tokenizeString Token.Cmdline data in
        Execute.execute scope buf in

    (* Run all lines of user input *)
    let runInput () =
        runString (String.concat "\n" (List.rev !lines)) in

    (* Road any files provided by the user, before launching REPL *)
    let runUserFiles () =
        List.iter runTargetFiles targets in

    (* The user is entering code -- read it all and then run it *)
    let handleCode () =
        (* Keep reading lines if continued with \ *)
        while (isContinued !line) do promptAndReadLine "..> " done;

        (* Now run the accumulated lines *)
        try
            let result = runInput () in
            print_endline (Pretty.replDisplay result true);
            flush stdout;
            ()
        with Failure e ->
            print_endline e;

            (* Flush stdout so any output is immediately visible *)
            flush stdout in

    (* First, run emily's built-in repl functions *)
    print_endline (replHelpString ^ "\n");

    (* Next, run any files provided as arguments *)
    runUserFiles ();

    (* Intercept Control-C so it doesn't kill the REPL. *)
    Sys.catch_break true;

    try
        (* As long as the user hasn't sent EOF (Control-D), read input *)
        while true do
            (try
                (* Draw a prompt, and read one line of input *)
                promptAndReadLine ">>> ";

                (* Handle the user's input appropriately *)
                handleCode ()

            with Sys.Break ->
                (* Control-C should clear the line, draw a new prompt *)
                print_endline "");

            (* Empty lines, since they have all been executed *)
            lines := [];
        done;

    with End_of_file ->
        (* Time to exit the REPL *)
        print_endline "Done"
