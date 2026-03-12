let missing_artifacts artifacts =
  artifacts |> List.filter (fun path -> not (Sys.file_exists path))

let run ~artifacts =
  match Sys.getenv_opt "CONFIRM_PROD_DEPLOY" with
  | Some "1" ->
      let missing = missing_artifacts artifacts in
      if missing <> [] then
        Error ("Missing artifact(s): " ^ String.concat ", " missing)
      else if not (Wrangler.available ()) then
        Error "Wrangler not available for production deploy."
      else
        let result = Wrangler.deploy_prod () in
        (match result.status with
        | Unix.WEXITED 0 -> Ok "Production deploy completed."
        | _ -> Error ("Production deploy failed.\n" ^ result.stderr))
  | _ -> Error "Missing confirmation: set CONFIRM_PROD_DEPLOY=1"
