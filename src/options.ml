let version = "0.0 DEVELOPMENT"
let machineVersion = [0,0,0]

type executionTarget = Stdin | File of string

type optionSpec = {
    mutable targets : executionTarget list
}

let run = {targets=[]}

let () = 
    let targets = ref [] in
    let seenStdin = ref false in
    
    let targetParse t = targets := File t :: !targets in

    Arg.parse [
        ("-", Arg.Unit(fun () -> (* Arg's parser means the magic - argument must be passed in this way. *)
            if !seenStdin then failwith "Attempted to parse stdin twice; that doesn't make sense?"
                else seenStdin := true; targets := Stdin :: !targets
        ), "") (* No summary, this shouldn't be listed with options. *)
    ] targetParse

("Emily language interpreter: version " ^ version ^ {|

Sample usage:
    emily filename.em # Execute program
    emily -           # Execute from stdin
Options:|})

    ; run.targets <- List.rev !targets

