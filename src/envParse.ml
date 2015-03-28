let parse =
    List.iter @@ function
        ( (key, spec, _) : (Arg.key * Arg.spec * Arg.doc) ) ->
            try
                let value = Unix.getenv key in (* May fail *)
                match spec with
                    | Arg.Unit f -> f ()
                    | Arg.String f -> f value
                    | _ -> failwith "Internal error: Called envParse with an arg spec it was not designed to handle."
            with
                Not_found -> ()
