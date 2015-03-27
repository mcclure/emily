let parse =
    List.iter @@ function
        ( (key, spec, _) : (Arg.key * Arg.spec * Arg.doc) ) ->
            try
                let value = Unix.getenv key in (* May fail *)
                print_endline @@ "Map " ^ key ^ " to " ^ value
            with
                Not_found -> ()
