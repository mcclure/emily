let keyMutate f = List.map @@ function ((a, b, c) : (Arg.key list * Arg.spec * Arg.doc)) -> (f a, b, c)

let argPlusLimitations who = failwith @@ "Internal error: Called "^who^" with an arg spec it was not designed to handle."

let envParse =
    List.iter @@ function
        ( (key, spec, _) : (Arg.key * Arg.spec * Arg.doc) ) ->
            try
                let value = Unix.getenv key in (* May fail *)
                match spec with
                    | Arg.Unit f -> f ()
                    | Arg.String f -> f value
                    | _ -> argPlusLimitations "envParse"
            with
                Not_found -> ()

let argParse rules fallback usage =
    let lookup : (Arg.key, Arg.spec) Hashtbl.t = Hashtbl.create(1) in
    List.iter (function (key, spec, _) -> Hashtbl.replace lookup key spec) rules;
    let rest : string list ref = ref @@ Array.to_list Sys.argv in
    let consume () = match !rest with | [] -> None | next::more -> (rest := more; Some next) in
    let rec proceed () =
        match consume () with
            | None -> ()
            | Some key -> (match (CCHashtbl.get lookup key) with
                | Some spec -> (match spec with
                        | Arg.Unit f -> f ()
                        | Arg.String f -> (match consume () with
                                | None -> print_endline "MISSING!"
                                | Some arg -> f arg
                            )
                        | _ -> argPlusLimitations "argParse"
                    )
                | None ->
                    if (String.length key > 0 && String.get key 0 == '-') then
                        print_endline "FAIL"
                    else
                        fallback key
            );
            proceed()
    in ignore @@ consume(); proceed() (* Discard argv[0] and start *)

let parseEquals rules withFallback s =
    try
        let splitAt = String.index s '=' in
        let key = String.sub s 0 splitAt in
        let value = String.sub s (splitAt+1) ((String.length s)-splitAt-1)
        in print_endline @@ "Key:"^key^",Value:"^value
    with
        Not_found -> withFallback s
