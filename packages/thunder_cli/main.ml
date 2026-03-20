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

let parse_compiled_runtime_path args default =
  let explicit = parse_kv args "--compiled-runtime" default in
  if explicit <> default then explicit else parse_kv args "--wasm" default

let string_of_compile_target = function
  | Thunder_cli_lib.Project_layout.Js -> "js"
  | Thunder_cli_lib.Project_layout.Wasm -> "wasm"

let parse_compile_target args default =
  let requested = parse_kv args "--target" (string_of_compile_target default) in
  match Thunder_cli_lib.Thunder_config.compile_target_of_string requested with
  | Ok Thunder_cli_lib.Thunder_config.Js -> Ok Thunder_cli_lib.Project_layout.Js
  | Ok Thunder_cli_lib.Thunder_config.Wasm -> Ok Thunder_cli_lib.Project_layout.Wasm
  | Error msg -> Error msg

let default_artifacts layout extra =
  let base =
    [ layout.Thunder_cli_lib.Project_layout.manifest_path;
      layout.Thunder_cli_lib.Project_layout.wrangler_template_path ]
  in
  let with_assets =
    match layout.Thunder_cli_lib.Project_layout.assets_dir with
    | Some path when Sys.file_exists path -> path :: base
    | _ -> base
  in
  with_assets @ extra

let run_preview args =
  match Thunder_cli_lib.Project_layout.default_result () with
  | Error msg ->
      prerr_endline msg;
      1
  | Ok defaults ->
      (match parse_compile_target args defaults.Thunder_cli_lib.Project_layout.compile_target with
      | Error msg ->
          prerr_endline msg;
          2
      | Ok compile_target ->
          let metadata = parse_kv args "--metadata" ".thunder/preview.json" in
          let compiled_runtime =
            parse_compiled_runtime_path args
              defaults.Thunder_cli_lib.Project_layout.compiled_runtime_path
          in
          let manifest_path = parse_kv args "--manifest-path" defaults.Thunder_cli_lib.Project_layout.manifest_path in
          let _runtime = parse_kv args "--runtime" "worker_runtime/index.mjs" in
          let wrangler_template =
            parse_kv args "--wrangler-template"
              defaults.Thunder_cli_lib.Project_layout.wrangler_template_path
          in
          let deploy_dir = parse_kv args "--deploy-dir" defaults.Thunder_cli_lib.Project_layout.deploy_dir in
          let framework_root =
            parse_kv args "--framework-root" defaults.Thunder_cli_lib.Project_layout.framework_root
          in
          let extras = parse_repeated args "--artifact" in
          match
            Thunder_cli_lib.Project_layout.with_overrides_result ~compile_target
              ~compiled_runtime_path:compiled_runtime ~manifest_path
              ~wrangler_template_path:wrangler_template ~deploy_dir ~framework_root ()
          with
          | Error msg ->
              prerr_endline msg;
              1
          | Ok layout ->
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
                  1)

let run_deploy_prod args =
  match Thunder_cli_lib.Project_layout.default_result () with
  | Error msg ->
      prerr_endline msg;
      1
  | Ok defaults ->
      (match parse_compile_target args defaults.Thunder_cli_lib.Project_layout.compile_target with
      | Error msg ->
          prerr_endline msg;
          2
      | Ok compile_target ->
          let compiled_runtime =
            parse_compiled_runtime_path args
              defaults.Thunder_cli_lib.Project_layout.compiled_runtime_path
          in
          let manifest_path = parse_kv args "--manifest-path" defaults.Thunder_cli_lib.Project_layout.manifest_path in
          let _runtime = parse_kv args "--runtime" "worker_runtime/index.mjs" in
          let wrangler_template =
            parse_kv args "--wrangler-template"
              defaults.Thunder_cli_lib.Project_layout.wrangler_template_path
          in
          let deploy_dir = parse_kv args "--deploy-dir" defaults.Thunder_cli_lib.Project_layout.deploy_dir in
          let framework_root =
            parse_kv args "--framework-root" defaults.Thunder_cli_lib.Project_layout.framework_root
          in
          let extras = parse_repeated args "--artifact" in
          match
            Thunder_cli_lib.Project_layout.with_overrides_result ~compile_target
              ~compiled_runtime_path:compiled_runtime ~manifest_path
              ~wrangler_template_path:wrangler_template ~deploy_dir ~framework_root ()
          with
          | Error msg ->
              prerr_endline msg;
              1
          | Ok layout ->
              (match
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
                  1))

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

let run_version () =
  print_endline Thunder_cli_lib.Version.current;
  0

let () =
  let argv = Array.to_list Sys.argv in
  match argv with
  | _ :: ("--version" | "version") :: _ -> exit (run_version ())
  | _ :: "doctor" :: _ -> exit (run_doctor ())
  | _ :: "init" :: args -> exit (run_init args)
  | _ :: "new" :: args -> exit (run_new args)
  | _ :: "preview-publish" :: args -> exit (run_preview args)
  | _ :: "deploy-prod" :: args -> exit (run_deploy_prod args)
  | _ ->
      prerr_endline
        "Usage: thunder (version | --version | new <project-name> | init [project-name] | doctor | preview-publish | deploy-prod) [--target js|wasm] [--metadata PATH] [--compiled-runtime PATH] [--manifest-path PATH] [--runtime PATH] [--wrangler-template PATH] [--deploy-dir PATH] [--framework-root PATH] [--artifact PATH]";
      exit 2
