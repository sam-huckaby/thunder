type staged = {
  deploy_dir : string;
  config_path : string;
  runtime_path : string;
  app_abi_path : string;
  bootstrap_path : string option;
  compiled_runtime_path : string;
  manifest_path : string;
  assets_dir : string option;
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

let option_iter2 f left right =
  match (left, right) with
  | Some a, Some b -> f a b
  | _ -> ()

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

let extract_durable_object_classes config_contents =
  config_contents
  |> String.split_on_char '\n'
  |> List.filter_map (fun line ->
         let trimmed = trim line in
         if String.starts_with ~prefix:"class_name =" trimmed then
           match List.rev (String.split_on_char '=' trimmed) with
           | value :: _ ->
               let value = trim value in
               let len = String.length value in
               if len >= 2 && value.[0] = '"' && value.[len - 1] = '"' then
                 Some (String.sub value 1 (len - 2))
               else Some value
           | [] -> None
         else None)

let append_durable_object_exports ~runtime_dst ~class_names =
  if class_names = [] then ()
  else
    let existing = read_file runtime_dst in
    let additions =
      class_names
      |> List.map (fun class_name ->
             Printf.sprintf
               "\nexport class %s {\n  async fetch(_request) {\n    return new Response(\"Thunder Durable Object placeholder\", { status: 501 });\n  }\n}\n"
               class_name)
      |> String.concat ""
    in
    write_file runtime_dst (existing ^ additions)

let quoted value = Printf.sprintf "%S" value

let render_development_manifest manifest =
  let optional_string_field key = function
    | Some value -> Printf.sprintf "  %s: %s,\n" key (quoted value)
    | None -> ""
  in
  "export default {\n"
  ^ Printf.sprintf "  abi_version: %d,\n" manifest.Deploy_manifest.abi_version
  ^ Printf.sprintf "  app_id: %s,\n" (quoted manifest.app_id)
  ^ Printf.sprintf
      "  runtime_kind: %s,\n"
      (quoted
         (match manifest.runtime_kind with Deploy_manifest.Js -> "js" | Deploy_manifest.Wasm -> "wasm"))
  ^ Printf.sprintf "  runtime_entry: %s,\n" (quoted manifest.runtime_entry)
  ^ Printf.sprintf "  app_abi: %s,\n" (quoted manifest.app_abi)
  ^ optional_string_field "generated_wasm_assets" manifest.generated_wasm_assets
  ^ Printf.sprintf "  compiled_runtime_backend: %s,\n"
      (quoted manifest.compiled_runtime_backend)
  ^ optional_string_field "bootstrap_module" manifest.bootstrap_module
  ^ Printf.sprintf "  compiled_runtime: %s,\n" (quoted manifest.compiled_runtime)
  ^ optional_string_field "assets_dir" manifest.assets_dir
  ^ "};\n"

let runtime_support_files =
  [ "index.mjs";
    "request_context.mjs";
    "binding_rpc.mjs";
    "app_abi.mjs";
    "development_manifest.mjs";
    "compiled_js_runtime_backend.mjs";
    "compiled_runtime_backend.mjs";
    "compiled_runtime_bootstrap.mjs" ]

let copy_runtime_support_files ~runtime_src ~framework_root ~deploy_dir =
  let deploy_runtime_dir = Filename.concat deploy_dir "worker_runtime" in
  let app_runtime_dir = Filename.dirname runtime_src in
  let framework_runtime_dir = Filename.concat framework_root "worker_runtime" in
  List.iter
    (fun name ->
      let app_src = Filename.concat app_runtime_dir name in
      let framework_src = Filename.concat framework_runtime_dir name in
      let src =
        if Sys.file_exists app_src then Some app_src
        else if Sys.file_exists framework_src then Some framework_src
        else None
      in
      match src with
      | Some src -> copy_file ~src ~dst:(Filename.concat deploy_runtime_dir name)
      | None -> ())
    runtime_support_files

let stage ~deploy_dir ~wrangler_template_path ~manifest_path ~framework_root =
  match Deploy_manifest.parse ~manifest_path with
  | Error e -> Error e
  | Ok manifest ->
      let manifest_src = manifest_path in
      let resolve relative =
        Deploy_manifest.resolve_reference ~framework_root ~manifest_path relative
      in
      let runtime_src = resolve manifest.runtime_entry in
      let app_abi_src = resolve manifest.app_abi in
      let compiled_backend_src = resolve manifest.compiled_runtime_backend in
      let compiled_runtime_src = resolve manifest.compiled_runtime in
      let generated_wasm_assets_src = Option.map resolve manifest.generated_wasm_assets in
      let bootstrap_src = Option.map resolve manifest.bootstrap_module in
      let assets_src = Option.map resolve manifest.assets_dir in
      let required_paths =
        [ Some wrangler_template_path;
          Some manifest_src;
          Some runtime_src;
          Some app_abi_src;
          generated_wasm_assets_src;
          Some compiled_backend_src;
          bootstrap_src;
          Some compiled_runtime_src;
          assets_src ]
        |> List.filter_map Fun.id
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
        let generated_wasm_assets_dst = Option.map target_from_manifest manifest.generated_wasm_assets in
        let compiled_backend_dst = target_from_manifest manifest.compiled_runtime_backend in
        let compiled_dst = target_from_manifest manifest.compiled_runtime in
        let assets_dst = Option.map target_from_manifest manifest.assets_dir in
        let bootstrap_dst = Option.map target_from_manifest manifest.bootstrap_module in
        let config_contents = read_file wrangler_template_path |> render_wrangler_config in
        let durable_object_classes = extract_durable_object_classes config_contents in
        copy_runtime_support_files ~runtime_src ~framework_root ~deploy_dir;
        copy_file ~src:runtime_src ~dst:runtime_dst;
        append_durable_object_exports ~runtime_dst ~class_names:durable_object_classes;
        write_file (Filename.concat deploy_dir "worker_runtime/development_manifest.mjs")
          (render_development_manifest manifest);
        copy_file ~src:app_abi_src ~dst:app_abi_dst;
        option_iter2 (fun src dst -> copy_file ~src ~dst) generated_wasm_assets_src
          generated_wasm_assets_dst;
        copy_file ~src:compiled_backend_src ~dst:compiled_backend_dst;
        option_iter2 (fun src dst -> copy_file ~src ~dst) bootstrap_src bootstrap_dst;
        copy_file ~src:compiled_runtime_src ~dst:compiled_dst;
        copy_file ~src:manifest_src ~dst:manifest_dst;
        option_iter2 (fun src dst -> copy_dir ~src ~dst) assets_src assets_dst;
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
