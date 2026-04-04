type ops = { deploy_worker : workdir:string -> config_path:string -> runtime_path:string -> Wrangler.result }

let default_ops =
  {
    deploy_worker =
      (fun ~workdir ~config_path ~runtime_path ->
        Wrangler.deploy_prod ~workdir:(Some workdir) ~config_path ~runtime_path:(Some runtime_path));
  }

let relative_to_workdir ~workdir path =
  let prefix = workdir ^ "/" in
  if String.starts_with ~prefix path then String.sub path (String.length prefix) (String.length path - String.length prefix)
  else Filename.basename path

let string_of_status = function
  | Unix.WEXITED code -> "exit(" ^ string_of_int code ^ ")"
  | Unix.WSIGNALED signal -> "signal(" ^ string_of_int signal ^ ")"
  | Unix.WSTOPPED signal -> "stopped(" ^ string_of_int signal ^ ")"

let run ?timestamp ~ops ~worker_name ~config_path ~state_path state =
  let workdir = Filename.dirname config_path in
  let runtime_path = relative_to_workdir ~workdir (Filename.concat workdir "worker_runtime/index.mjs") in
  let result = ops.deploy_worker ~workdir ~config_path:(Filename.basename config_path) ~runtime_path in
  match result.Wrangler.status with
  | Unix.WEXITED 0 ->
      let worker =
        {
          Cloudflare_state.script_name = Some worker_name;
          bootstrapped = true;
          last_deploy_at = timestamp;
        }
      in
      let updated = { state with Cloudflare_state.worker = Some worker } in
      (match Cloudflare_state.write ~path:state_path updated with
      | Error _ as e -> e
      | Ok () -> Ok updated)
  | status ->
      Error
        ("Wrangler bootstrap deploy failed: " ^ string_of_status status ^ "\n" ^ result.stderr)
