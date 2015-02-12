(* Parse and validate command line arguments. *)

let version = "0.2b"
let fullVersion = ("Emily language interpreter: Version " ^ version)

type executionTarget = Stdin | File of string | Literal of string

type optionSpec = {
    (* Execution args *)
    mutable targets : executionTarget list;
    mutable repl : bool;
    mutable stepMacro : bool;
    mutable trace : bool;
    mutable trackObjects : bool;
    mutable traceSet : bool;

    (* Things to do instead of execution *)
    mutable disassemble : bool;
    mutable disassembleVerbose : bool;
    mutable printVersion : bool;
    mutable printMachineVersion : bool;
}

let run = {
    targets=[];
    repl=false;
    stepMacro=false; trace=false; trackObjects=false; traceSet = false;
    disassemble=false; disassembleVerbose=false; printVersion = false; printMachineVersion = false;
}

let () =
    let targets = ref [] in
    let seenStdin = ref false in

    let targetParse t = targets := File t :: !targets in

    let usage = (fullVersion ^ {|

Sample usage:
    emily filename.em    # Execute program
    emily -              # Execute from stdin
    emily -e "println 3" # Execute from command line
    emily -i             # Execute REPL

Options:|})

    in let versionSpec key = (key, Arg.Unit(fun () -> run.printVersion <- true), {|Print interpreter version|})

    in let args = [
        ("-", Arg.Unit(fun () -> (* Arg's parser means the magic - argument must be passed in this way. *)
            if !seenStdin then failwith "Attempted to parse stdin twice; that doesn't make sense?"
                else seenStdin := true; targets := Stdin :: !targets
        ), ""); (* No summary, this shouldn't be listed with options. *)

        (* Args *)
        ("-e", Arg.String(fun f ->
            targets := Literal f :: !targets
        ), "Execute code inline");

        ("-i", Arg.Unit(fun f ->
            run.repl <- true
            (*targets := Repl :: !targets*)
        ), "Execute REPL");

        versionSpec "-v";
        versionSpec "--version";

        ("--machine-version", Arg.Unit(fun () -> run.printMachineVersion <- true), {|Print interpreter version (machine-readable-- number only)|});

        (* For supporting Emily development itself *)
        ("--debug-dis",   Arg.Unit(fun () -> run.disassemble <- true),        {|Print "disassembled" code and exit|});
        ("--debug-disv",  Arg.Unit(fun () -> run.disassembleVerbose <- true), {|Print "disassembled" code with position data and exit|});
        ("--debug-macro", Arg.Unit(fun () -> run.stepMacro <- true),          {|Print results of each individual macro evaluation|});
        ("--debug-trace", Arg.Unit(fun () -> run.trace <- true),              "When executing, print interpreter state");
        ("--debug-track", Arg.Unit(fun () -> run.trackObjects <- true),       {|When executing, give all objects a unique "!id" member|});
        ("--debug-set",   Arg.Unit(fun () -> run.traceSet <- true),           {|When executing, print object contents on each set|});
        ("--debug-run",   Arg.Unit(fun () ->
            run.trace <- true;
            run.trackObjects <- true;
            run.traceSet <- true
        ),  {|When executing, set all runtime trace type options|});
    ]

    in Arg.parse args targetParse usage;

    (* Arguments are parsed; either short-circuit with an informational message, or store targets *)
    if run.printMachineVersion then print_endline version else
    if run.printVersion then print_endline fullVersion else
      run.targets <- List.rev !targets;
    if (run.repl) then () else match run.targets with
        | [] -> Arg.usage args usage; exit 1 (* No targets! *)
        | _  -> ()
