let sanitize_project_name name =
  String.map (function '-' -> '_' | c -> c) name

let library_module_name package_name =
  String.capitalize_ascii (package_name ^ "_app")

let ensure_absent path =
  if Sys.file_exists path then Error ("Destination already exists: " ^ path) else Ok ()

let ensure_missing path =
  if Sys.file_exists path then Error ("Refusing to overwrite existing path: " ^ path) else Ok ()

let rec ensure_dir path =
  if path = "." || path = "/" || path = "" then ()
  else if Sys.file_exists path then ()
  else (
    ensure_dir (Filename.dirname path);
    Unix.mkdir path 0o755)

let write_file path contents =
  ensure_dir (Filename.dirname path);
  let oc = open_out_bin path in
  Fun.protect
    ~finally:(fun () -> close_out_noerr oc)
    (fun () -> output_string oc contents)

let read_file path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let rec copy_tree ~src ~dst =
  if Sys.is_directory src then (
    ensure_dir dst;
    Sys.readdir src
    |> Array.iter (fun name ->
           let src_path = Filename.concat src name in
           let dst_path = Filename.concat dst name in
           if not (Filename.check_suffix src_path ".DS_Store") then
             copy_tree ~src:src_path ~dst:dst_path))
  else write_file dst (read_file src)

let symlink_or_copy ~src ~dst =
  try Unix.symlink src dst with _ -> copy_tree ~src ~dst

let framework_root () = Thunder_config.read_if_exists ~config_path:(Project_layout.config_path ()) |> fun config ->
  Option.value config.framework_root ~default:(Project_layout.discover_framework_root ())

let use_installed_framework_home framework_root =
  let installed_current = Framework_home.current_dir () in
  framework_root = installed_current
  || String.starts_with ~prefix:(Framework_home.default_base_dir ()) framework_root

let dune_project_template ~package_name =
  Printf.sprintf
    "(lang dune 3.13)\n(name %s)\n(generate_opam_files false)\n(using directory-targets 0.1)\n\n(package\n (name %s)\n (synopsis \"Thunder app %s\"))\n"
    package_name package_name package_name

let root_dune_template () =
  {dune|
(subdir dist/worker
 (rule
  (alias worker-build)
  (targets thunder_runtime.mjs (dir thunder_runtime.assets))
  (deps %{dep:../../worker/entry.bc})
  (action
   (run
    wasm_of_ocaml
    compile
     -o
      thunder_runtime.mjs
      %{dep:../../worker/entry.bc})))

 (rule
  (alias worker-build)
  (target manifest.json)
  (action
   (write-file
    manifest.json
    "{\n  \"abi_version\": 1,\n  \"app_id\": \"thunder-app\",\n  \"runtime_entry\": \"../../worker_runtime/index.mjs\",\n  \"app_abi\": \"../../worker_runtime/app_abi.mjs\",\n  \"generated_wasm_assets\": \"../../worker_runtime/generated_wasm_assets.mjs\",\n  \"compiled_runtime_backend\": \"../../worker_runtime/compiled_runtime_backend.mjs\",\n  \"bootstrap_module\": \"../../worker_runtime/compiled_runtime_bootstrap.mjs\",\n  \"compiled_runtime\": \"thunder_runtime.mjs\",\n  \"assets_dir\": \"thunder_runtime.assets\"\n}\n"))))

(subdir worker_runtime
 (rule
  (alias worker-build)
  (target generated_wasm_assets.mjs)
  (deps (glob_files ../dist/worker/thunder_runtime.assets/*.wasm)
        %{dep:../vendor/thunder-framework/scripts/generate_wasm_asset_map.py})
  (action
   (run python3 %{dep:../vendor/thunder-framework/scripts/generate_wasm_asset_map.py}
    ../dist/worker/thunder_runtime.assets %{target}))))

(alias
 (name worker-build)
 (deps
   dist/worker/thunder_runtime.mjs
   dist/worker/manifest.json
   dist/worker/thunder_runtime.assets
   worker_runtime/generated_wasm_assets.mjs
   worker/entry.bc))

(rule
 (alias preview-publish)
 (deps
  (alias worker-build)
  %{dep:wrangler.toml}
  %{dep:dist/worker/thunder_runtime.mjs}
  %{dep:dist/worker/manifest.json}
  %{dep:worker_runtime/index.mjs}
  %{dep:worker_runtime/app_abi.mjs}
  %{dep:worker_runtime/compiled_runtime_backend.mjs}
  %{dep:worker_runtime/compiled_runtime_bootstrap.mjs}
  %{dep:worker_runtime/generated_wasm_assets.mjs}
  %{exe:vendor/thunder-framework/packages/thunder_cli/main.exe})
 (locks thunder_preview_publish)
(action
  (chdir %{workspace_root}
    (setenv THUNDER_FRAMEWORK_ROOT %{workspace_root}/vendor/thunder-framework
     (run %{exe:vendor/thunder-framework/packages/thunder_cli/main.exe}
     preview-publish
     --metadata
     %{workspace_root}/../../.thunder/preview.json
     --wrangler-template
     wrangler.toml
     --deploy-dir
     deploy
     --manifest-path
     %{dep:dist/worker/manifest.json}
     --wasm
     %{dep:dist/worker/thunder_runtime.mjs}
     --artifact
     %{dep:dist/worker/thunder_runtime.assets})))))

(rule
 (alias deploy-prod)
 (deps
  (alias worker-build)
  %{dep:wrangler.toml}
  %{dep:dist/worker/thunder_runtime.mjs}
  %{dep:dist/worker/manifest.json}
  %{dep:worker_runtime/index.mjs}
  %{dep:worker_runtime/app_abi.mjs}
  %{dep:worker_runtime/compiled_runtime_backend.mjs}
  %{dep:worker_runtime/compiled_runtime_bootstrap.mjs}
  %{dep:worker_runtime/generated_wasm_assets.mjs}
  %{exe:vendor/thunder-framework/packages/thunder_cli/main.exe})
(action
  (chdir %{workspace_root}
    (setenv THUNDER_FRAMEWORK_ROOT %{workspace_root}/vendor/thunder-framework
     (run %{exe:vendor/thunder-framework/packages/thunder_cli/main.exe}
     deploy-prod
     --wrangler-template
     wrangler.toml
     --deploy-dir
     deploy
     --manifest-path
     %{dep:dist/worker/manifest.json}
     --wasm
     %{dep:dist/worker/thunder_runtime.mjs}
     --artifact
     %{dep:dist/worker/thunder_runtime.assets})))))

(alias
 (name default)
 (deps (alias worker-build) (alias preview-publish)))
|dune}

let app_dune_template ~package_name =
  Printf.sprintf
    "(library\n (name %s_app)\n (modules routes middleware)\n (libraries thunder))\n"
    package_name

let worker_dune_template ~package_name =
  Printf.sprintf
    "(executable\n (name entry)\n (modes byte)\n (modules entry)\n (libraries %s_app thunder.worker))\n"
    package_name

let bin_dune_template ~package_name =
  Printf.sprintf
    "(executable\n (name main)\n (public_name %s-local)\n (modules main)\n (libraries %s_app thunder))\n"
    package_name package_name

let package_json_template ~project_name =
  Printf.sprintf
    "{\n  \"name\": \"%s\",\n  \"private\": true,\n  \"type\": \"module\",\n  \"scripts\": {\n    \"wrangler\": \"wrangler\",\n    \"dev\": \"wrangler dev\",\n    \"deploy\": \"wrangler deploy\"\n  },\n  \"devDependencies\": {\n    \"wrangler\": \"^4.72.0\"\n  }\n}\n"
    project_name

let wrangler_template ~project_name =
  Printf.sprintf
    "name = \"%s\"\nmain = \"worker_runtime/index.mjs\"\naccount_id = \"<your-cloudflare-account-id>\"\ncompatibility_date = \"2026-03-12\"\ncompatibility_flags = [\"nodejs_compat\"]\nfind_additional_modules = true\nworkers_dev = true\n\n[observability]\nenabled = true\n"
    project_name

let thunder_json_template ~framework_root =
  Printf.sprintf
    "{\n  \"app_module\": \"Routes\",\n  \"worker_entry_path\": \"worker/entry.ml\",\n  \"compiled_runtime_path\": \"dist/worker/thunder_runtime.mjs\",\n  \"wrangler_template_path\": \"wrangler.toml\",\n  \"deploy_dir\": \"deploy\",\n  \"framework_root\": \"%s\"\n}\n"
    framework_root

let app_routes_template () =
  {routes|let app =
  Thunder.router
    [
      Thunder.get "/"
        (Thunder.handler (fun _ ->
             Thunder.html
               {html|
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Thunder</title>
    <style>
      :root {
        color-scheme: dark;
      }

      * {
        box-sizing: border-box;
      }

      html,
      body {
        min-height: 100%;
        margin: 0;
      }

      body {
        display: grid;
        place-items: center;
        padding: 2rem;
        background:
          radial-gradient(circle at 50% 18%, rgba(255, 255, 255, 0.16), rgba(255, 255, 255, 0.04) 18%, rgba(255, 255, 255, 0) 42%),
          radial-gradient(circle at 22% 30%, rgba(11, 28, 48, 0.92), rgba(4, 9, 16, 0) 44%),
          radial-gradient(circle at 78% 18%, rgba(7, 21, 37, 0.78), rgba(4, 9, 16, 0) 40%),
          linear-gradient(180deg, #0a1420 0%, #050a12 58%, #02040a 100%);
        color: #f8fbff;
        font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Georgia, serif;
      }

      main {
        width: min(100%, 42rem);
        text-align: center;
      }

      h1 {
        margin: 0;
        font-size: clamp(2.5rem, 7vw, 5.5rem);
        font-weight: 600;
        letter-spacing: 0.04em;
        text-shadow: 0 0 24px rgba(255, 255, 255, 0.18);
      }

      p {
        margin: 1rem 0 0;
        font-size: clamp(1rem, 2.4vw, 1.25rem);
        line-height: 1.7;
        color: rgba(248, 251, 255, 0.84);
      }
    </style>
  </head>
  <body>
    <main>
      <h1>Hello from Thunder</h1>
      <p>Edit app/routes.ml to start building.</p>
    </main>
  </body>
</html>
|html}));
      Thunder.get "/health"
        (Thunder.handler (fun _ -> Thunder.json "{\"ok\":true}"));
    ]
|routes}

let app_routes_mli_template () = "val app : Thunder.handler\n"

let app_middleware_template () =
  "let apply app =\n  app\n"

let app_middleware_mli_template () = "val apply : Thunder.handler -> Thunder.handler\n"

let worker_entry_template ~package_name =
  let app_module = library_module_name package_name in
  Printf.sprintf
    "let app = %s.Routes.app |> %s.Middleware.apply\n\nlet () = Entry.export app\n"
    app_module app_module

let bin_main_template ~package_name =
  let app_module = library_module_name package_name in
  Printf.sprintf
    "let app = %s.Routes.app |> %s.Middleware.apply\n\nlet () =\n  let request = Thunder.Request.make ~meth:Thunder.Method.GET ~url:\"https://example.com/\" () in\n  let response = Thunder.Handler.run app request in\n  print_endline (Thunder.Response.body_string response)\n"
    app_module app_module

let gitignore_template () =
  "_build/\nnode_modules/\n.thunder/\nvendor/\n*.install\n"

let readme_template ~project_name =
  Printf.sprintf
    "# %s\n\nThis app was scaffolded by Thunder.\n\n## Current status\n\nThunder currently links or copies framework internals into `vendor/thunder-framework` so the app can build. When Thunder is installed through the current installer flow, that path is expected to be a local link into the installed framework home.\n\n## Where to edit app code\n\n- `app/routes.ml` for routes and responses\n- `app/middleware.ml` for app middleware\n- `worker/entry.ml` is the tiny Worker export wrapper and should rarely need edits\n\n## Useful commands\n\n- `npm install`\n- `dune build`\n- `dune runtest`\n- `dune exec ./bin/main.exe`\n- `THUNDER_SMOKE_WORKER_NAME=\"your-existing-worker\" bash scripts/preview_smoke.sh auto`\n\n## Preview metadata\n\nThunder writes preview state to app-root `.thunder/preview.json`.\n\nUseful fields include:\n\n- `artifact_hash`\n- `last_version_id`\n- `last_preview_url`\n"
    project_name

let test_dune_template ~package_name =
  Printf.sprintf
    "(test\n (name smoke_test)\n (modules smoke_test)\n (libraries %s_app thunder))\n"
    package_name

let smoke_test_template ~package_name =
  let app_module = library_module_name package_name in
  Printf.sprintf
    "let () =\n  let request = Thunder.Request.make ~meth:Thunder.Method.GET ~url:\"https://example.com/\" () in\n  let response = Thunder.Handler.run %s.Routes.app request in\n  if Thunder.Status.code (Thunder.Response.status response) <> 200 then failwith \"expected 200\"\n"
    app_module

let files_to_write ~scaffold_framework_root ~package_name ~project_name =
  [
    ("dune-project", dune_project_template ~package_name);
    ("dune", root_dune_template ());
    ("package.json", package_json_template ~project_name);
    ("wrangler.toml", wrangler_template ~project_name);
    ("thunder.json", thunder_json_template ~framework_root:scaffold_framework_root);
    (".gitignore", gitignore_template ());
    ("README.md", readme_template ~project_name);
    ("app/dune", app_dune_template ~package_name);
    ("app/routes.ml", app_routes_template ());
    ("app/routes.mli", app_routes_mli_template ());
    ("app/middleware.ml", app_middleware_template ());
    ("app/middleware.mli", app_middleware_mli_template ());
    ("bin/dune", bin_dune_template ~package_name);
    ("bin/main.ml", bin_main_template ~package_name);
    ("worker/dune", worker_dune_template ~package_name);
    ("worker/entry.ml", worker_entry_template ~package_name);
    ("test/dune", test_dune_template ~package_name);
    ("test/smoke_test.ml", smoke_test_template ~package_name);
  ]

let link_framework_home ~destination ~framework_root =
  let framework_home = Filename.concat destination "vendor/thunder-framework" in
  ensure_dir (Filename.concat destination "vendor");
  if use_installed_framework_home framework_root then symlink_or_copy ~src:framework_root ~dst:framework_home
  else (
    ensure_dir framework_home;
    List.iter
      (fun name ->
        let src = Filename.concat framework_root name in
        let dst = Filename.concat framework_home name in
        symlink_or_copy ~src ~dst)
      [ "dune-project"; "packages"; "worker_runtime"; "scripts" ])

let copy_runtime_bundle ~destination ~framework_root =
  let worker_runtime_root = Filename.concat destination "worker_runtime" in
  ensure_dir worker_runtime_root;
  List.iter
    (fun name ->
      copy_tree
        ~src:(Filename.concat framework_root (Filename.concat "worker_runtime" name))
        ~dst:(Filename.concat worker_runtime_root name))
    [ "index.mjs"; "app_abi.mjs"; "compiled_runtime_backend.mjs";
      "compiled_runtime_bootstrap.mjs" ]

let write_project ~destination ~project_name ~must_be_absent =
  let package_name = sanitize_project_name project_name in
  let framework_root = framework_root () in
  let scaffold_framework_root = "vendor/thunder-framework" in
  let files = files_to_write ~scaffold_framework_root ~package_name ~project_name in
  let path_check = if must_be_absent then ensure_absent else (fun _ -> Ok ()) in
  match path_check destination with
  | Error _ as e -> e
  | Ok () ->
      ensure_dir destination;
      ensure_dir (Filename.concat destination "app");
      ensure_dir (Filename.concat destination "bin");
      ensure_dir (Filename.concat destination "worker");
      ensure_dir (Filename.concat destination "test");
      let rec ensure_targets = function
        | [] -> Ok ()
        | (relative_path, _) :: rest ->
            let target = Filename.concat destination relative_path in
            (match ensure_missing target with
            | Error _ as e -> e
            | Ok () -> ensure_targets rest)
      in
      (match ensure_targets files with
      | Error e -> Error e
      | Ok () ->
          link_framework_home ~destination ~framework_root;
          copy_runtime_bundle ~destination ~framework_root;
          List.iter
            (fun (relative_path, contents) ->
              write_file (Filename.concat destination relative_path) contents)
            files;
          Ok ())

let create_project ~destination ~project_name =
  write_project ~destination ~project_name ~must_be_absent:true

let init_project ~destination ~project_name =
  write_project ~destination ~project_name ~must_be_absent:false
