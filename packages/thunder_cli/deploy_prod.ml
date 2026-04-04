let missing_artifacts artifacts =
  artifacts |> List.filter (fun path -> not (Sys.file_exists path))

let relative_to_workdir ~workdir path =
  let prefix = workdir ^ "/" in
  if String.starts_with ~prefix path then String.sub path (String.length prefix) (String.length path - String.length prefix)
  else Filename.basename path

let run ~artifacts ~deploy_dir ~wrangler_template_path ~manifest_path ~runtime_path:_
    ~framework_root =
  match Sys.getenv_opt "CONFIRM_PROD_DEPLOY" with
  | Some "1" ->
      (match Deploy_manifest.referenced_paths ~framework_root ~manifest_path with
      | Error e -> Error e
      | Ok resolved ->
          let missing = missing_artifacts (resolved @ artifacts) in
          if missing <> [] then
            Error ("Missing artifact(s): " ^ String.concat ", " missing)
          else if not (Wrangler.available ()) then
            Error "Wrangler not available for production deploy."
          else
            match
              Deploy_layout.stage ~deploy_dir ~wrangler_template_path ~manifest_path
                ~framework_root
            with
            | Error e -> Error e
            | Ok staged ->
                let workdir = Filename.dirname staged.config_path in
                let staged_runtime_path = relative_to_workdir ~workdir staged.runtime_path in
                let result =
                  Wrangler.deploy_prod ~workdir:(Some workdir)
                    ~config_path:(Filename.basename staged.config_path)
                    ~runtime_path:(Some staged_runtime_path)
                in
                match result.status with
                | Unix.WEXITED 0 -> Ok "Production deploy completed."
                | _ -> Error ("Production deploy failed.\n" ^ result.stderr))
  | _ -> Error "Missing confirmation: set CONFIRM_PROD_DEPLOY=1"
