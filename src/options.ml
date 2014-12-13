(* Parse and validate command line arguments. *)

let version = "0.0 DEVELOPMENT"
let machineVersion = [0,0,0]

type executionTarget = Stdin | File of string | Literal of string

type optionSpec = {
    mutable targets : executionTarget list;
    mutable disassemble : bool;
    mutable disassembleVerbose : bool;
    mutable trace : bool;
    mutable trackObjects : bool;
    mutable traceSet : bool;
}

let run = {
    targets=[];
    disassemble=false; disassembleVerbose=false; trace=false; trackObjects=false; traceSet = false;
}

let () =
    let targets = ref [] in
    let seenStdin = ref false in

    let targetParse t = targets := File t :: !targets in

    let usage =
("Emily language interpreter: version " ^ version ^ {|

Sample usage:
    emily filename.em    # Execute program
    emily -              # Execute from stdin
    emily -e "println 3" # Execute from command line

Options:|})

    in let args = [
        ("-", Arg.Unit(fun () -> (* Arg's parser means the magic - argument must be passed in this way. *)
            if !seenStdin then failwith "Attempted to parse stdin twice; that doesn't make sense?"
                else seenStdin := true; targets := Stdin :: !targets
        ), ""); (* No summary, this shouldn't be listed with options. *)

        (* Args *)
        ("-e", Arg.String(fun f ->
            targets := Literal f :: !targets
        ), "Execute code inline");

        (* For supporting Emily development itself *)
        ("--debug-dis",   Arg.Unit(fun () -> run.disassemble <- true),        {|Print "disassembled" code and exit|});
        ("--debug-disv",  Arg.Unit(fun () -> run.disassembleVerbose <- true), {|Print "disassembled" code with position data and exit|});
        ("--debug-trace", Arg.Unit(fun () -> run.trace <- true),              "When executing, print interpreter state");
        ("--debug-track", Arg.Unit(fun () -> run.trackObjects <- true),       {|When executing, give all objects a unique "!id" member|});
        ("--debug-set",   Arg.Unit(fun () -> run.traceSet <- true),           {|When executing, print object contents on each set|});
    ]

    in Arg.parse args targetParse usage

    ; match !targets with
        | [] -> Arg.usage args usage; exit 1
        | t  -> run.targets <- List.rev t

