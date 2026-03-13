type staged = {
  deploy_dir : string;
  config_path : string;
  runtime_path : string;
  bootstrap_path : string;
  compiled_runtime_path : string;
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

let stage ~deploy_dir ~wrangler_template_path ~runtime_path ~compiled_runtime_path =
  let bootstrap_src =
    Filename.concat (Filename.dirname runtime_path) "compiled_runtime_bootstrap.mjs"
  in
  let assets_src =
    Filename.concat (Filename.dirname compiled_runtime_path) "thunder_runtime.assets"
  in
  let required_paths =
    [ wrangler_template_path; runtime_path; bootstrap_src; compiled_runtime_path; assets_src ]
  in
  let missing = required_paths |> List.filter (fun path -> not (Sys.file_exists path)) in
  if missing <> [] then
    Error
      ("Missing deploy input(s): " ^ String.concat ", " missing
     ^ ". Run dune build to regenerate deploy assets.")
  else
    let deploy_runtime_dir = Filename.concat deploy_dir "worker_runtime" in
    let deploy_dist_dir = Filename.concat deploy_dir "dist/worker" in
    let deploy_assets_dir = Filename.concat deploy_dist_dir "thunder_runtime.assets" in
    let config_path = Filename.concat deploy_dir "wrangler.toml" in
    let runtime_dst = Filename.concat deploy_runtime_dir "index.mjs" in
    let bootstrap_dst = Filename.concat deploy_runtime_dir "compiled_runtime_bootstrap.mjs" in
    let compiled_dst = Filename.concat deploy_dist_dir "thunder_runtime.mjs" in
    let config_contents = read_file wrangler_template_path |> render_wrangler_config in
    ensure_dir deploy_runtime_dir;
    ensure_dir deploy_dist_dir;
    copy_file ~src:runtime_path ~dst:runtime_dst;
    copy_file ~src:bootstrap_src ~dst:bootstrap_dst;
    copy_file ~src:compiled_runtime_path ~dst:compiled_dst;
    copy_dir ~src:assets_src ~dst:deploy_assets_dir;
    write_file config_path config_contents;
    Ok
      {
        deploy_dir;
        config_path;
        runtime_path = runtime_dst;
        bootstrap_path = bootstrap_dst;
        compiled_runtime_path = compiled_dst;
        assets_dir = deploy_assets_dir;
      }
