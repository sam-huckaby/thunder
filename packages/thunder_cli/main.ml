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

let runtime_bootstrap_path runtime =
  Filename.concat (Filename.dirname runtime) "compiled_runtime_bootstrap.mjs"

let default_artifacts wasm runtime wrangler_template extra =
  let base = [ wasm; runtime; runtime_bootstrap_path runtime; wrangler_template ] in
  let with_assets =
    let assets_dir = Filename.concat (Filename.dirname wasm) "thunder_runtime.assets" in
    if Sys.file_exists assets_dir then assets_dir :: base else base
  in
  with_assets @ extra

let run_preview args =
  let metadata = parse_kv args "--metadata" ".thunder/preview.json" in
  let wasm = parse_kv args "--wasm" "dist/worker/thunder_runtime.mjs" in
  let runtime = parse_kv args "--runtime" "worker_runtime/index.mjs" in
  let wrangler_template = parse_kv args "--wrangler-template" "wrangler.toml" in
  let deploy_dir = parse_kv args "--deploy-dir" "deploy" in
  let extras = parse_repeated args "--artifact" in
  let config =
    Thunder_cli_lib.Preview_publish.
      {
        metadata_path = metadata;
        artifacts = default_artifacts wasm runtime wrangler_template extras;
        deploy_dir;
        wrangler_template_path = wrangler_template;
        runtime_path = runtime;
        compiled_runtime_path = wasm;
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
  let wasm = parse_kv args "--wasm" "dist/worker/thunder_runtime.mjs" in
  let runtime = parse_kv args "--runtime" "worker_runtime/index.mjs" in
  let wrangler_template = parse_kv args "--wrangler-template" "wrangler.toml" in
  let deploy_dir = parse_kv args "--deploy-dir" "deploy" in
  let extras = parse_repeated args "--artifact" in
  match
    Thunder_cli_lib.Deploy_prod.run
      ~artifacts:(default_artifacts wasm runtime wrangler_template extras)
      ~deploy_dir ~wrangler_template_path:wrangler_template ~runtime_path:runtime
      ~compiled_runtime_path:wasm
  with
  | Ok msg ->
      print_endline msg;
      0
  | Error msg ->
      prerr_endline msg;
      1

let () =
  let argv = Array.to_list Sys.argv in
  match argv with
  | _ :: "preview-publish" :: args -> exit (run_preview args)
  | _ :: "deploy-prod" :: args -> exit (run_deploy_prod args)
  | _ ->
      prerr_endline
        "Usage: thunder_cli (preview-publish|deploy-prod) [--metadata PATH] [--wasm PATH] [--runtime PATH] [--wrangler-template PATH] [--deploy-dir PATH] [--artifact PATH]";
      exit 2
