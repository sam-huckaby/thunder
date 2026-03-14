let home_dir () =
  Option.value (Sys.getenv_opt "HOME") ~default:(Sys.getcwd ())

let default_base_dir () =
  match Sys.getenv_opt "THUNDER_HOME" with
  | Some path -> path
  | None ->
      let xdg =
        match Sys.getenv_opt "XDG_DATA_HOME" with
        | Some path -> path
        | None -> Filename.concat (home_dir ()) ".local/share"
      in
      Filename.concat xdg "thunder"

let current_dir () = Filename.concat (default_base_dir ()) "current"

let versioned_dir ~version =
  Filename.concat (Filename.concat (default_base_dir ()) "versions") version
