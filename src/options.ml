(* Parse and validate command line arguments. *)

let version = "0.3b"
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
    mutable packagePath : string option;
    mutable projectPath : string option;

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
    packagePath=None;projectPath=None;
    disassemble=false; disassembleVerbose=false; printVersion = false; printMachineVersion = false;
}

let keyMutateArgument    = ArgPlus.keyMutate @@ fun l -> "--" ^ (String.concat "-" l)
let keyMutateEnvironment = ArgPlus.keyMutate @@ fun l -> "EMILY_" ^ (String.concat "_" @@ List.map String.uppercase l)

let buildPathSetSpec name action whatIs =
    (name, Arg.String(action), "Directory root for packages loaded from \"" ^ whatIs ^ "\"")

let () =
    let targets = ref [] in
    let seenStdin = ref false in

    let usage = (fullVersion ^ {|

Sample usage:
    emily filename.em     # Execute program
    emily -               # Execute from stdin
    emily -e "println 3"  # Execute from command line
    emily -i              # Run in interactive mode (REPL)
    emily -i filename.em  # ...after executing this program

Options:|})

    in let versionSpec key = (key, Arg.Unit(fun () -> run.printVersion <- true), {|Print interpreter version|})

    in let executeArgs = [ (* Basic arguments *)
        ("-", Arg.Unit(fun () -> (* Arg's parser means the magic - argument must be passed in this way. *)
            if !seenStdin then failwith "Attempted to parse stdin twice; that doesn't make sense?"
                else seenStdin := true; targets := Stdin :: !targets
        ), ""); (* No summary, this shouldn't be listed with options. *)

        (* Args *)
        ("-e", Arg.String(fun f ->
            targets := Literal f :: !targets
        ), "Execute code inline");

    ] @ (if%const [%getenv "BUILD_INCLUDE_REPL"] <> "" then [

        (* Only include if Makefile requested REPL *)
        ("-i", Arg.Unit(fun f ->
            run.repl <- true
        ), "Enter interactive mode (REPL)");

    ] else []) @ [ (* Normal arguments continue *)

        versionSpec "-v";
        versionSpec "--version";

        ("--machine-version", Arg.Unit(fun () -> run.printMachineVersion <- true), {|Print interpreter version (machine-readable-- number only)|});
    ]

    in let environmentArgs = [ (* "Config" arguments which can be also set with env vars *)
        buildPathSetSpec ["package";"path"]          (fun a -> run.packagePath <- Some a)  "package";
        buildPathSetSpec ["project";"path"]          (fun a -> run.projectPath <- Some a)  "project";
    ]

    in let debugArgs = [ (* For supporting Emily development itself-- separate out to sort last in help *)
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

    in let args = executeArgs @ (keyMutateArgument environmentArgs) @ debugArgs

    in let targetParse t = targets := File t :: !targets

    in
    ArgPlus.envParse (keyMutateEnvironment environmentArgs);
    ArgPlus.argParse args targetParse usage (fun _ ->
        (* Arguments are parsed; either short-circuit with an informational message, or store targets *)
        if run.printMachineVersion then print_endline version else
        if run.printVersion then print_endline fullVersion else (
            run.targets <- List.rev !targets;
            if (run.repl) then () else match run.targets with
                | [] -> raise @@ ArgPlus.Help 1 (* No targets! Fail and print help. *)
                | _  -> ()
        )
    )
