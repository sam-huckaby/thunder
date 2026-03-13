type staged = {
  deploy_dir : string;
  config_path : string;
  runtime_path : string;
  app_abi_path : string;
  bootstrap_path : string;
  compiled_runtime_path : string;
  manifest_path : string;
  assets_dir : string;
}

let rec ensure_dir path =
  if path = "." || path = "/" || path = "" then ()
  else if Sys.file_exists path then ()
  else (
    ensure_dir (Filename.dirname path);
    Unix.mkdir path 0o755)

let read_file path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () ->
      let len = in_channel_length ic in
      really_input_string ic len)

let write_file path contents =
  ensure_dir (Filename.dirname path);
  let oc = open_out_bin path in
  Fun.protect
    ~finally:(fun () -> close_out_noerr oc)
    (fun () -> output_string oc contents)

let copy_file ~src ~dst = write_file dst (read_file src)

let normalize_path path =
  let absolute = String.length path > 0 && path.[0] = '/' in
  let parts = String.split_on_char '/' path in
  let rec fold acc = function
    | [] -> List.rev acc
    | "" :: rest -> fold acc rest
    | "." :: rest -> fold acc rest
    | ".." :: rest ->
        let acc = match acc with [] -> [] | _ :: tl -> tl in
        fold acc rest
    | part :: rest -> fold (part :: acc) rest
  in
  let joined = String.concat "/" (fold [] parts) in
  if absolute then "/" ^ joined else joined

let rec copy_dir ~src ~dst =
  ensure_dir dst;
  Sys.readdir src
  |> Array.iter (fun name ->
         let src_path = Filename.concat src name in
         let dst_path = Filename.concat dst name in
         if Sys.is_directory src_path then copy_dir ~src:src_path ~dst:dst_path
         else copy_file ~src:src_path ~dst:dst_path)

let trim = String.trim

let line_has_key key line =
  let prefix = key ^ " =" in
  String.starts_with ~prefix (trim line)

let render_wrangler_config template =
  let lines = String.split_on_char '\n' template in
  let has_main = List.exists (line_has_key "main") lines in
  let has_find_additional_modules =
    List.exists (line_has_key "find_additional_modules") lines
  in
  let rewritten =
    lines
    |> List.map (fun line ->
           if line_has_key "main" line then "main = \"worker_runtime/index.mjs\""
           else if line_has_key "find_additional_modules" line then
             "find_additional_modules = true"
           else line)
  in
  let with_main =
    if has_main then rewritten
    else "main = \"worker_runtime/index.mjs\"" :: rewritten
  in
  let with_modules =
    if has_find_additional_modules then with_main
    else
      let rec insert_after_main acc = function
        | [] -> List.rev ("find_additional_modules = true" :: acc)
        | line :: rest when line_has_key "main" line ->
            List.rev_append acc
              (line :: "find_additional_modules = true" :: rest)
        | line :: rest -> insert_after_main (line :: acc) rest
      in
      insert_after_main [] with_main
  in
  String.concat "\n" with_modules

let stage ~deploy_dir ~wrangler_template_path ~manifest_path =
  match Deploy_manifest.parse ~manifest_path with
  | Error e -> Error e
  | Ok manifest ->
      let manifest_src = manifest_path in
      let manifest_src_dir = Filename.dirname manifest_src in
      let resolve relative = normalize_path (Filename.concat manifest_src_dir relative) in
      let runtime_src = resolve manifest.runtime_entry in
      let app_abi_src = resolve manifest.app_abi in
      let generated_wasm_assets_src = resolve manifest.generated_wasm_assets in
      let compiled_backend_src = resolve manifest.compiled_runtime_backend in
      let bootstrap_src = resolve manifest.bootstrap_module in
      let compiled_runtime_src = resolve manifest.compiled_runtime in
      let assets_src = resolve manifest.assets_dir in
      let required_paths =
        [ wrangler_template_path; manifest_src; runtime_src; app_abi_src;
          generated_wasm_assets_src; compiled_backend_src; bootstrap_src;
          compiled_runtime_src; assets_src ]
      in
      let missing = required_paths |> List.filter (fun path -> not (Sys.file_exists path)) in
      if missing <> [] then
        Error
          ("Missing deploy input(s): " ^ String.concat ", " missing
         ^ ". Run dune build to regenerate deploy assets.")
      else
        let deploy_manifest_dir = Filename.concat deploy_dir "dist/worker" in
        let manifest_dst = Filename.concat deploy_manifest_dir "manifest.json" in
        let manifest_dst_dir = Filename.dirname manifest_dst in
        let target_from_manifest relative =
          normalize_path (Filename.concat manifest_dst_dir relative)
        in
        let config_path = Filename.concat deploy_dir "wrangler.toml" in
        let runtime_dst = target_from_manifest manifest.runtime_entry in
        let app_abi_dst = target_from_manifest manifest.app_abi in
        let generated_wasm_assets_dst =
          target_from_manifest manifest.generated_wasm_assets
        in
        let compiled_backend_dst = target_from_manifest manifest.compiled_runtime_backend in
        let compiled_dst = target_from_manifest manifest.compiled_runtime in
        let assets_dst = target_from_manifest manifest.assets_dir in
        let bootstrap_dst = target_from_manifest manifest.bootstrap_module in
        let config_contents = read_file wrangler_template_path |> render_wrangler_config in
        copy_file ~src:runtime_src ~dst:runtime_dst;
        copy_file ~src:app_abi_src ~dst:app_abi_dst;
        copy_file ~src:generated_wasm_assets_src ~dst:generated_wasm_assets_dst;
        copy_file ~src:compiled_backend_src ~dst:compiled_backend_dst;
        copy_file ~src:bootstrap_src ~dst:bootstrap_dst;
        copy_file ~src:compiled_runtime_src ~dst:compiled_dst;
        copy_file ~src:manifest_src ~dst:manifest_dst;
        copy_dir ~src:assets_src ~dst:assets_dst;
        write_file config_path config_contents;
        Ok
          {
            deploy_dir;
            config_path;
            runtime_path = runtime_dst;
            app_abi_path = app_abi_dst;
            bootstrap_path = bootstrap_dst;
            compiled_runtime_path = compiled_dst;
            manifest_path = manifest_dst;
            assets_dir = assets_dst;
          }
