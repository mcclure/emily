let keyMutate f = List.map @@ function ((a, b, c) : (Arg.key list * Arg.spec * Arg.doc)) -> (f a, b, c)

let argPlusLimitations who = failwith @@ "Internal error: Called "^who^" with an arg spec it was not designed to handle."

(* Rule methods can raise Arg.Bad, Arg.Help, ArgPlus.Help or ArgPlus.Complete *)
exception Complete    (* Success, stop processing arguments *)
exception Help of int (* Argument is exit code *)

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
                Not_found -> () (* Nothing wrong with an env var we don't recognize. *)

let argParse rules fallback usage onComplete =
    let lookup : (Arg.key, Arg.spec) Hashtbl.t = Hashtbl.create(1) in
    List.iter (function (key, spec, _) -> Hashtbl.replace lookup key spec) rules;
    let rest : string list ref = ref @@ Array.to_list Sys.argv in
    let consume () = match !rest with | [] -> None | next::more -> (rest := more; Some next) in
    let rec proceed () =
        match consume () with
            | None -> ()
            | Some key -> (match (CCHashtbl.get lookup key) with
                | Some Arg.Unit f -> f ()
                | Some Arg.String f -> (match consume () with
                        | None -> raise @@ Arg.Bad ("option '"^key^"' needs an argument.")
                        | Some arg -> f arg
                    )
                | Some _ -> argPlusLimitations "argParse"
                | None ->
                    let keyLen = String.length key in
                    if (keyLen > 0 && String.get key 0 == '-') then
                        let eqAt = try Some (String.index key '=') with Not_found -> None in
                        match eqAt with
                            | Some splitAt ->
                                let subKey = String.sub key 0 splitAt in
                                let subValue = String.sub key (splitAt+1) (keyLen-splitAt-1) in
                                (match (CCHashtbl.get lookup subKey) with
                                    | Some Arg.Unit _ -> raise @@ Arg.Bad ("option '"^subKey^"' does not take an argument.")
                                    | Some Arg.String f -> f subValue
                                    | Some _ -> argPlusLimitations "argParse"
                                    | None -> raise @@ Arg.Bad ("unknown option '"^subKey^"'"))
                            | None -> raise @@ Arg.Bad ("unknown option '"^key^"'")
                    else
                        fallback key
            );
            proceed()
    in let name = match consume() with Some s -> s
        | None -> "(INTERNAL ERROR)" (* None implies argc==0, so we won't ever be displaying this anyway? *)
    in try
        (try
            proceed() (* Discard argv[0] and start *)
        with
            | Arg.Help _ -> raise @@ Help 0 (* FIXME: What is the argument to Arg.Help for? It isn't documented. *)
            | Complete -> ());
        onComplete !rest
    with
        | Help i -> Arg.usage rules usage; exit i
        | Arg.Bad s -> prerr_endline @@ name^": "^s; Arg.usage rules usage; exit 1
