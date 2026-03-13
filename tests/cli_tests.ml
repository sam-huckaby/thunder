let assert_true msg cond = if not cond then failwith msg

let assert_eq msg expected actual =
  if expected <> actual then failwith (msg ^ " expected=" ^ expected ^ " actual=" ^ actual)

let with_temp_file prefix content f =
  let path = Filename.temp_file prefix ".tmp" in
  let oc = open_out path in
  output_string oc content;
  close_out oc;
  Fun.protect ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
    (fun () -> f path)

let with_temp_path prefix f =
  let path = Filename.temp_file prefix ".tmp" in
  if Sys.file_exists path then Sys.remove path;
  Fun.protect ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
    (fun () -> f path)

let rec rm_rf path =
  if Sys.file_exists path then
    if Sys.is_directory path then (
      Sys.readdir path
      |> Array.iter (fun name -> rm_rf (Filename.concat path name));
      Unix.rmdir path)
    else Sys.remove path

let with_temp_dir prefix f =
  let base = Filename.temp_file prefix ".tmp" in
  if Sys.file_exists base then Sys.remove base;
  Unix.mkdir base 0o755;
  Fun.protect ~finally:(fun () -> rm_rf base) (fun () -> f base)

let write_file path content =
  let oc = open_out path in
  Fun.protect ~finally:(fun () -> close_out_noerr oc)
    (fun () -> output_string oc content)

let () =
  with_temp_file "thunder-artifact" "hello" (fun artifact ->
      match Thunder_cli_lib.Artifact_hash.compute [ artifact ] with
      | Error e -> failwith e
      | Ok h1 ->
          (match Thunder_cli_lib.Artifact_hash.compute [ artifact ] with
          | Error e -> failwith e
          | Ok h2 -> assert_true "stable hash" (h1 = h2)));
  ()

let () =
  with_temp_path "thunder-metadata" (fun metadata_path ->
      let metadata : Thunder_cli_lib.Preview_publish.metadata =
        {
          artifact_hash = Some "abc";
          last_upload_at = Some "2026-03-12T00:00:00Z";
          last_version_id = Some "v1";
          last_preview_url = Some "https://preview.example";
          raw_wrangler_output = Some "uploaded";
        }
      in
      Thunder_cli_lib.Preview_publish.write_metadata ~metadata_path metadata;
      let loaded = Thunder_cli_lib.Preview_publish.read_metadata ~metadata_path in
      assert_eq "metadata hash" (Option.get metadata.artifact_hash)
        (Option.get loaded.artifact_hash);
      assert_eq "metadata version" (Option.get metadata.last_version_id)
        (Option.get loaded.last_version_id));
  ()

let () =
  with_temp_file "thunder-legacy-metadata" "hash=legacy123\n" (fun metadata_path ->
      let hash = Thunder_cli_lib.Artifact_hash.read_previous_hash ~metadata_path in
      assert_eq "legacy hash migration" "legacy123" (Option.get hash));
  ()

let () =
  with_temp_dir "thunder-manifest" (fun dir ->
      let worker_runtime_dir = Filename.concat dir "worker_runtime" in
      let dist_dir = Filename.concat dir "dist/worker" in
      Unix.mkdir worker_runtime_dir 0o755;
      Unix.mkdir (Filename.concat dir "dist") 0o755;
      Unix.mkdir dist_dir 0o755;
      let manifest_path = Filename.concat dist_dir "manifest.json" in
      write_file manifest_path
        "{\"abi_version\":1,\"app_id\":\"test-app\",\"runtime_entry\":\"../../worker_runtime/index.mjs\",\"app_abi\":\"../../worker_runtime/app_abi.mjs\",\"generated_wasm_assets\":\"../../worker_runtime/generated_wasm_assets.mjs\",\"compiled_runtime_backend\":\"../../worker_runtime/compiled_runtime_backend.mjs\",\"bootstrap_module\":\"../../worker_runtime/compiled_runtime_bootstrap.mjs\",\"compiled_runtime\":\"thunder_runtime.mjs\",\"assets_dir\":\"thunder_runtime.assets\"}\n";
      match Thunder_cli_lib.Deploy_manifest.parse ~manifest_path with
      | Error e -> failwith e
      | Ok manifest ->
          assert_eq "manifest app id" "test-app" manifest.app_id;
          assert_eq "manifest generated assets" "../../worker_runtime/generated_wasm_assets.mjs"
            manifest.generated_wasm_assets;
          assert_eq "manifest backend" "../../worker_runtime/compiled_runtime_backend.mjs"
            manifest.compiled_runtime_backend;
          assert_eq "manifest compiled runtime" "thunder_runtime.mjs"
            manifest.compiled_runtime);
  ()

let () =
  let info =
    Thunder_cli_lib.Wrangler.parse_preview_info
      ~stdout:
        "Upload complete\nVersion ID: 4f9f4f4a\nPreview URL: https://edge.example.workers.dev"
      ~stderr:""
  in
  assert_eq "parsed version" "4f9f4f4a" (Option.get info.version_id);
  assert_eq "parsed url" "https://edge.example.workers.dev"
    (Option.get info.preview_url)

let () =
  with_temp_file "thunder-artifact" "hello" (fun artifact ->
      with_temp_dir "thunder-preview" (fun dir ->
          let metadata_path = Filename.concat dir "preview.txt" in
          let runtime_dir = Filename.concat dir "worker_runtime" in
          let dist_dir = Filename.concat dir "dist/worker" in
          let assets_dir = Filename.concat dist_dir "thunder_runtime.assets" in
          let runtime_path = Filename.concat runtime_dir "index.mjs" in
          let app_abi_path = Filename.concat runtime_dir "app_abi.mjs" in
          let generated_wasm_assets_path = Filename.concat runtime_dir "generated_wasm_assets.mjs" in
          let bootstrap_path = Filename.concat runtime_dir "compiled_runtime_bootstrap.mjs" in
          let wasm_path = Filename.concat dist_dir "thunder_runtime.mjs" in
          let manifest_path = Filename.concat dist_dir "manifest.json" in
          let wrangler_path = Filename.concat dir "wrangler.toml" in
          Unix.mkdir runtime_dir 0o755;
          Unix.mkdir (Filename.concat dir "dist") 0o755;
          Unix.mkdir dist_dir 0o755;
          Unix.mkdir assets_dir 0o755;
          write_file runtime_path "export default {}\n";
          write_file app_abi_path "export async function init() { return {}; }\nexport async function handle() { return new Response(); }\n";
          write_file generated_wasm_assets_path
            "export function getBundledWasmAsset() { return null; }\nexport function getBundledWasmModule() { return null; }\nexport function listBundledWasmAssets() { return []; }\n";
          write_file (Filename.concat runtime_dir "compiled_runtime_backend.mjs")
            "export async function initCompiledRuntimeBackend() { return {}; }\nexport async function handleCompiledRuntimePayload() { return '{}'; }\nexport function resetCompiledRuntimeBackendForTests() {}\n";
          write_file bootstrap_path "export const compiledRuntimeInitError = null;\n";
          write_file wasm_path "compiled-runtime\n";
          write_file manifest_path
            "{\"abi_version\":1,\"app_id\":\"test-app\",\"runtime_entry\":\"../../worker_runtime/index.mjs\",\"app_abi\":\"../../worker_runtime/app_abi.mjs\",\"generated_wasm_assets\":\"../../worker_runtime/generated_wasm_assets.mjs\",\"compiled_runtime_backend\":\"../../worker_runtime/compiled_runtime_backend.mjs\",\"bootstrap_module\":\"../../worker_runtime/compiled_runtime_bootstrap.mjs\",\"compiled_runtime\":\"thunder_runtime.mjs\",\"assets_dir\":\"thunder_runtime.assets\"}\n";
          let artifacts =
            [ artifact; runtime_path; app_abi_path; generated_wasm_assets_path; bootstrap_path;
              wasm_path; manifest_path; wrangler_path; assets_dir ]
          in
          let hash =
            match
              Thunder_cli_lib.Artifact_hash.compute_with_manifest ~manifest_path artifacts
            with
            | Ok value -> value
            | Error e -> failwith e
          in
          write_file (Filename.concat assets_dir "chunk.wasm") "wasm\n";
          write_file wrangler_path "name = \"test\"\nmain = \"worker_runtime/index.mjs\"\n";
          Thunder_cli_lib.Preview_publish.write_metadata ~metadata_path
            {
              artifact_hash = Some hash;
              last_upload_at = None;
              last_version_id = None;
              last_preview_url = None;
              raw_wrangler_output = None;
            };
          match
            Thunder_cli_lib.Preview_publish.run
              {
                metadata_path;
                artifacts;
                deploy_dir = Filename.concat dir "deploy";
                wrangler_template_path = wrangler_path;
                manifest_path;
                force = false;
              }
          with
          | Ok msg -> assert_true "skip unchanged" (String.length msg > 0)
          | Error err -> failwith err));
  print_endline "cli_tests: ok"
