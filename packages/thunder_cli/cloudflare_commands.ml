type provision_ops = {
  account_id : unit -> (string option, string) result;
  provision : Cloudflare_provision.ops;
  build_worker : unit -> (unit, string) result;
  bootstrap : Cloudflare_bootstrap.ops;
}

let stage message = prerr_endline ("[thunder] " ^ message)
let debug_line enabled message = if enabled then prerr_endline ("[thunder][debug] " ^ message)

let string_of_status = function
  | Unix.WEXITED code -> "exit(" ^ string_of_int code ^ ")"
  | Unix.WSIGNALED signal -> "signal(" ^ string_of_int signal ^ ")"
  | Unix.WSTOPPED signal -> "stopped(" ^ string_of_int signal ^ ")"

let default_account_id () =
  let result = Wrangler.whoami () in
  match result.status with
  | Unix.WEXITED 0 -> Ok (Wrangler.parse_account_id ~stdout:result.stdout ~stderr:result.stderr)
  | status ->
      Error
        ("Wrangler whoami failed: " ^ string_of_status status ^ "\n" ^ result.stderr)

let default_build_worker () =
  match Sys.command "dune build @worker-build" with
  | 0 -> Ok ()
  | code -> Error ("Failed to build worker artifacts with dune build @worker-build (exit " ^ string_of_int code ^ ").")

let default_provision_ops =
  {
    account_id = default_account_id;
    provision = Cloudflare_provision.default_ops;
    build_worker = default_build_worker;
    bootstrap = Cloudflare_bootstrap.default_ops;
  }

let read_file path =
  let ic = open_in_bin path in
  Fun.protect ~finally:(fun () -> close_in_noerr ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let write_file path contents =
  let oc = open_out_bin path in
  Fun.protect ~finally:(fun () -> close_out_noerr oc) (fun () -> output_string oc contents)

let replace_all text ~pattern ~replacement =
  let pattern_len = String.length pattern in
  if pattern_len = 0 then text
  else
    let buffer = Buffer.create (String.length text + 32) in
    let rec loop index =
      if index >= String.length text then ()
      else if index + pattern_len <= String.length text
              && String.sub text index pattern_len = pattern
      then (
        Buffer.add_string buffer replacement;
        loop (index + pattern_len))
      else (
        Buffer.add_char buffer text.[index];
        loop (index + 1))
    in
    loop 0;
    Buffer.contents buffer

let read_worker_name path =
  if not (Sys.file_exists path) then None
  else
    let lines = String.split_on_char '\n' (read_file path) in
    lines
    |> List.find_map (fun line ->
           let trimmed = String.trim line in
           if String.starts_with ~prefix:"name =" trimmed then
             match List.rev (String.split_on_char '=' trimmed) with
             | value :: _ ->
                 let value = String.trim value in
                 let len = String.length value in
                 if len >= 2 && value.[0] = '"' && value.[len - 1] = '"' then
                   Some (String.sub value 1 (len - 2))
                 else Some value
             | [] -> None
            else None)

let resolve_built_path path =
  if Sys.file_exists path then path
  else
    let candidate = Filename.concat "_build/default" path in
    if Sys.file_exists candidate then candidate else path

let patch_generated_app_dune_for_installed_thunder path =
  if not (Sys.file_exists path) then Ok ()
  else
    let contents = read_file path in
    let updated =
      contents
      |> replace_all
           ~pattern:"%{exe:vendor/thunder-framework/packages/thunder_cli/main.exe}"
           ~replacement:"%{bin:thunder}"
      |> replace_all
           ~pattern:"(setenv THUNDER_FRAMEWORK_ROOT %{workspace_root}/vendor/thunder-framework\n"
           ~replacement:""
      |> replace_all ~pattern:"worker_runtime/index.mjs)))))" ~replacement:"worker_runtime/index.mjs))))"
    in
    if updated <> contents then write_file path updated;
    Ok ()

let action_to_string = function
  | Cloudflare_provision.Create -> "created"
  | Cloudflare_provision.Reuse -> "reused"
  | Cloudflare_provision.Adopt -> "adopted"
  | Cloudflare_provision.Wire -> "wired"

let summarize_steps steps =
  steps
  |> List.map (fun step ->
         let name = Option.value step.Cloudflare_provision.name ~default:"<unnamed>" in
         Printf.sprintf "- %s %s (%s)" (action_to_string step.action) step.binding name)
  |> String.concat "\n"

let run_provision_with ~debug ~ops ~config_path =
  stage "Loading Thunder config";
  match Thunder_config.read ~config_path with
  | Error _ as e -> e
  | Ok config ->
      (match config.cloudflare with
      | None -> Error "Missing cloudflare provisioning config in thunder.json"
      | Some cloudflare ->
          stage "Loading existing Cloudflare state";
          let wrangler_template_path = Option.value config.wrangler_template_path ~default:"wrangler.toml" in
          let state_path = Cloudflare_state.default_path () in
          let root_dune_path = "dune" in
          let state = Cloudflare_state.read_if_exists ~path:state_path in
          let timestamp = Printf.sprintf "%.0f" (Unix.time ()) in
          let worker_name = read_worker_name wrangler_template_path in
          debug_line debug ("config_path=" ^ config_path);
          debug_line debug ("wrangler_template_path=" ^ wrangler_template_path);
          debug_line debug ("state_path=" ^ state_path);
          debug_line debug ("root_dune_path=" ^ root_dune_path);
          debug_line debug
            ("worker_name=" ^ Option.value worker_name ~default:"<missing>");
          stage "Patching generated app dune for installed thunder";
          (match patch_generated_app_dune_for_installed_thunder root_dune_path with
          | Error _ as e -> e
          | Ok () ->
          stage "Inspecting authenticated Cloudflare account";
          (match ops.account_id () with
           | Error _ as e -> e
           | Ok account_id ->
              debug_line debug
                ("account_id=" ^ Option.value account_id ~default:"<missing>");
              (match
                 stage "Provisioning or reusing remote resources";
                    Cloudflare_provision.run_and_write ?account_id ?worker_name ~timestamp
                    ~ops:ops.provision ~state_path config state
                with
               | Error _ as e -> e
               | Ok (state, steps) ->
                   stage "Patching wrangler.toml with Thunder-managed bindings";
                   (match
                      Cloudflare_wrangler_config.apply_to_file ~config:cloudflare ~state
                        ~path:wrangler_template_path
                   with
                  | Error _ as e -> e
                  | Ok _ ->
                       let final_state_result =
                         match cloudflare.bootstrap_worker with
                         | Some false ->
                             stage "Skipping bootstrap deploy because bootstrap_worker is disabled";
                             Ok state
                         | _ ->
                             (match worker_name with
                             | None -> Error "Missing worker name in wrangler.toml"
                             | Some worker_name ->
                                 stage "Building worker artifacts for bootstrap deploy";
                                 (match ops.build_worker () with
                                 | Error _ as e -> e
                                 | Ok () ->
                                     stage "Staging deploy bundle";
                                     (match Project_layout.default_result () with
                                     | Error _ as e -> e
                                     | Ok layout ->
                                         let manifest_path = resolve_built_path layout.manifest_path in
                                         debug_line debug ("resolved manifest_path=" ^ manifest_path);
                                         debug_line debug ("deploy_dir=" ^ layout.deploy_dir);
                                         debug_line debug
                                           ("framework_root=" ^ layout.framework_root);
                                         (match
                                            Deploy_layout.stage
                                             ~deploy_dir:layout.deploy_dir
                                             ~wrangler_template_path:layout.wrangler_template_path
                                             ~manifest_path
                                             ~framework_root:layout.framework_root
                                         with
                                         | Error _ as e -> e
                                         | Ok staged ->
                                             stage "Running bootstrap deploy with Wrangler";
                                              Cloudflare_bootstrap.run ~timestamp ~ops:ops.bootstrap
                                                ~worker_name ~config_path:staged.config_path
                                                ~state_path state))))
                      in
                      (match final_state_result with
                      | Error _ as e -> e
                      | Ok _ ->
                          Ok
                            ("Cloudflare provision complete\n"
                            ^ summarize_steps steps
                            ^ "\nRun `thunder cloudflare status --pretty` to inspect the result.")))))))

let run_provision ~debug ~config_path = run_provision_with ~debug ~ops:default_provision_ops ~config_path
