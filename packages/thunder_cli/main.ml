let force_preview () =
  match Sys.getenv_opt "THUNDER_FORCE_PREVIEW" with
  | Some "1" -> true
  | _ -> false

let parse_kv args key default =
  let rec loop = function
    | [] -> default
    | k :: v :: _rest when k = key -> v
    | _ :: rest -> loop rest
  in
  loop args

let parse_repeated args key =
  let rec loop acc = function
    | [] -> List.rev acc
    | k :: v :: rest when k = key -> loop (v :: acc) rest
    | _ :: rest -> loop acc rest
  in
  loop [] args

let default_artifacts layout extra =
  let base =
    [ layout.Thunder_cli_lib.Project_layout.manifest_path;
      layout.Thunder_cli_lib.Project_layout.wrangler_template_path ]
  in
  let with_assets =
    if Sys.file_exists layout.assets_dir then layout.assets_dir :: base else base
  in
  with_assets @ extra

let run_preview args =
  let metadata = parse_kv args "--metadata" ".thunder/preview.json" in
  let wasm = parse_kv args "--wasm" (Thunder_cli_lib.Project_layout.default ()).compiled_runtime_path in
  let manifest_path = parse_kv args "--manifest-path" (Thunder_cli_lib.Project_layout.default ()).manifest_path in
  let _runtime = parse_kv args "--runtime" "worker_runtime/index.mjs" in
  let wrangler_template =
    parse_kv args "--wrangler-template" (Thunder_cli_lib.Project_layout.default ()).wrangler_template_path
  in
  let deploy_dir = parse_kv args "--deploy-dir" (Thunder_cli_lib.Project_layout.default ()).deploy_dir in
  let framework_root = parse_kv args "--framework-root" (Thunder_cli_lib.Project_layout.default ()).framework_root in
  let extras = parse_repeated args "--artifact" in
  let layout =
    Thunder_cli_lib.Project_layout.with_overrides ~compiled_runtime_path:wasm
      ~manifest_path ~wrangler_template_path:wrangler_template ~deploy_dir ~framework_root ()
  in
  let config =
    Thunder_cli_lib.Preview_publish.
      {
        metadata_path = metadata;
        artifacts = default_artifacts layout extras;
        deploy_dir = layout.Thunder_cli_lib.Project_layout.deploy_dir;
        wrangler_template_path = layout.Thunder_cli_lib.Project_layout.wrangler_template_path;
        manifest_path = layout.Thunder_cli_lib.Project_layout.manifest_path;
        framework_root = layout.Thunder_cli_lib.Project_layout.framework_root;
        force = force_preview ();
      }
  in
  match Thunder_cli_lib.Preview_publish.run config with
  | Ok msg ->
      print_endline msg;
      0
  | Error msg ->
      prerr_endline msg;
      1

let run_deploy_prod args =
  let wasm = parse_kv args "--wasm" (Thunder_cli_lib.Project_layout.default ()).compiled_runtime_path in
  let manifest_path = parse_kv args "--manifest-path" (Thunder_cli_lib.Project_layout.default ()).manifest_path in
  let _runtime = parse_kv args "--runtime" "worker_runtime/index.mjs" in
  let wrangler_template =
    parse_kv args "--wrangler-template" (Thunder_cli_lib.Project_layout.default ()).wrangler_template_path
  in
  let deploy_dir = parse_kv args "--deploy-dir" (Thunder_cli_lib.Project_layout.default ()).deploy_dir in
  let framework_root = parse_kv args "--framework-root" (Thunder_cli_lib.Project_layout.default ()).framework_root in
  let extras = parse_repeated args "--artifact" in
  let layout =
    Thunder_cli_lib.Project_layout.with_overrides ~compiled_runtime_path:wasm
      ~manifest_path ~wrangler_template_path:wrangler_template ~deploy_dir ~framework_root ()
  in
  match
    Thunder_cli_lib.Deploy_prod.run
      ~artifacts:(default_artifacts layout extras)
      ~deploy_dir:layout.Thunder_cli_lib.Project_layout.deploy_dir
      ~wrangler_template_path:layout.Thunder_cli_lib.Project_layout.wrangler_template_path
      ~manifest_path:layout.Thunder_cli_lib.Project_layout.manifest_path
      ~framework_root:layout.Thunder_cli_lib.Project_layout.framework_root
  with
  | Ok msg ->
      print_endline msg;
      0
  | Error msg ->
      prerr_endline msg;
      1

let run_new args =
  match args with
  | [ project_arg ] ->
      let destination =
        if Filename.is_relative project_arg then Filename.concat (Sys.getcwd ()) project_arg
        else project_arg
      in
      let project_name = Filename.basename destination in
      (match Thunder_cli_lib.Scaffold.create_project ~destination ~project_name with
      | Ok () ->
          print_endline ("Created Thunder app in " ^ destination);
          0
      | Error msg ->
          prerr_endline msg;
          1)
  | _ ->
      prerr_endline "Usage: thunder new <project-name>";
      2

let run_init args =
  match args with
  | [] ->
      let cwd = Sys.getcwd () in
      let project_name = Filename.basename cwd in
      (match Thunder_cli_lib.Scaffold.init_project ~destination:cwd ~project_name with
      | Ok () ->
          print_endline ("Initialized Thunder app in " ^ cwd);
          0
      | Error msg ->
          prerr_endline msg;
          1)
  | [ project_name ] ->
      let destination = Sys.getcwd () in
      (match Thunder_cli_lib.Scaffold.init_project ~destination ~project_name with
      | Ok () ->
          print_endline ("Initialized Thunder app in " ^ destination);
          0
      | Error msg ->
          prerr_endline msg;
          1)
  | _ ->
      prerr_endline "Usage: thunder init [project-name]";
      2

let run_doctor () =
  match Thunder_cli_lib.Doctor.run () with
  | Ok report ->
      print_endline report;
      0
  | Error msg ->
      prerr_endline msg;
      1

let () =
  let argv = Array.to_list Sys.argv in
  match argv with
  | _ :: "doctor" :: _ -> exit (run_doctor ())
  | _ :: "init" :: args -> exit (run_init args)
  | _ :: "new" :: args -> exit (run_new args)
  | _ :: "preview-publish" :: args -> exit (run_preview args)
  | _ :: "deploy-prod" :: args -> exit (run_deploy_prod args)
  | _ ->
      prerr_endline
        "Usage: thunder (new <project-name> | init [project-name] | doctor | preview-publish | deploy-prod) [--metadata PATH] [--wasm PATH] [--manifest-path PATH] [--runtime PATH] [--wrangler-template PATH] [--deploy-dir PATH] [--framework-root PATH] [--artifact PATH]";
      exit 2
