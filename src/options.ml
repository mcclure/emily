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

    let targetParse t =
        let v = match t with
            | "<>" ->
                if !seenStdin then failwith "Attempted to parse stdin twice; that doesn't make sense?"
                else seenStdin := true; Stdin
            | t -> File t in
        targets := v :: !targets
    in

    Arg.parse [] targetParse

("Emily language interpreter: version " ^ version ^ {|

Sample usage:
    emily filename.em # Execute program
    emily "<>"          # Execute from stdin
Options:|})

    ; run.targets <- List.rev !targets

