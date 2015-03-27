let rec parse (rules : (Arg.key * Arg.spec * Arg.doc) list) =
    match rules with
        | [] -> ()
        | (key, spec, _) :: moreRules ->
            (try
                let value = Unix.getenv key in (* May fail *)
                print_endline @@ "Map " ^ key ^ " to " ^ value
            with
                Not_found -> ());
            parse moreRules
