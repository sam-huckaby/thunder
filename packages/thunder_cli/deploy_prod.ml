let missing_artifacts artifacts =
  artifacts |> List.filter (fun path -> not (Sys.file_exists path))

let run ~artifacts ~deploy_dir ~wrangler_template_path ~manifest_path
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
                let result = Wrangler.deploy_prod ~config_path:staged.config_path in
                match result.status with
                | Unix.WEXITED 0 -> Ok "Production deploy completed."
                | _ -> Error ("Production deploy failed.\n" ^ result.stderr))
  | _ -> Error "Missing confirmation: set CONFIRM_PROD_DEPLOY=1"
