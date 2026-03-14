type t = {
  app_module : string option;
  worker_entry_path : string option;
  compiled_runtime_path : string option;
  wrangler_template_path : string option;
  deploy_dir : string option;
  framework_root : string option;
}

let empty =
  {
    app_module = None;
    worker_entry_path = None;
    compiled_runtime_path = None;
    wrangler_template_path = None;
    deploy_dir = None;
    framework_root = None;
  }

let default_path () = "thunder.json"

let read_file path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let trim = String.trim

let strip_quotes value =
  let value = trim value in
  let len = String.length value in
  if len >= 2 && value.[0] = '"' && value.[len - 1] = '"' then
    String.sub value 1 (len - 2)
  else value

let extract_value content key =
  let marker = Printf.sprintf "\"%s\"" key in
  let rec find_marker start =
    match String.index_from_opt content start '"' with
    | None -> None
    | Some idx ->
        let remaining = String.length content - idx in
        if remaining >= String.length marker
           && String.sub content idx (String.length marker) = marker
        then Some idx
        else find_marker (idx + 1)
  in
  match find_marker 0 with
  | None -> None
  | Some marker_idx ->
      let after_marker = marker_idx + String.length marker in
      (match String.index_from_opt content after_marker ':' with
      | None -> None
      | Some colon_idx ->
          let rec skip_ws idx =
            if idx >= String.length content then idx
            else
              match content.[idx] with
              | ' ' | '\n' | '\r' | '\t' -> skip_ws (idx + 1)
              | _ -> idx
          in
          let value_idx = skip_ws (colon_idx + 1) in
          if value_idx >= String.length content then None
          else if content.[value_idx] = '"' then
            let rec find_end idx =
              if idx >= String.length content then None
              else if content.[idx] = '"' then Some idx
              else find_end (idx + 1)
            in
            Option.map
              (fun end_idx -> String.sub content value_idx (end_idx - value_idx + 1))
              (find_end (value_idx + 1))
          else None)

let read ~config_path =
  if not (Sys.file_exists config_path) then
    Error ("Missing Thunder config: " ^ config_path)
  else
    let content = read_file config_path in
    let find key = Option.map strip_quotes (extract_value content key) in
    Ok
      {
        app_module = find "app_module";
        worker_entry_path = find "worker_entry_path";
        compiled_runtime_path = find "compiled_runtime_path";
        wrangler_template_path = find "wrangler_template_path";
        deploy_dir = find "deploy_dir";
        framework_root = find "framework_root";
      }

let read_if_exists ~config_path =
  if Sys.file_exists config_path then
    match read ~config_path with
    | Ok config -> config
    | Error _ -> empty
  else empty
