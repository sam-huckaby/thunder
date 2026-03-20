type runtime_kind = Js | Wasm

type t = {
  abi_version : int;
  app_id : string;
  runtime_kind : runtime_kind;
  runtime_entry : string;
  app_abi : string;
  generated_wasm_assets : string option;
  compiled_runtime_backend : string;
  bootstrap_module : string option;
  compiled_runtime : string;
  assets_dir : string option;
}

let runtime_kind_of_string = function
  | "js" -> Ok Js
  | "wasm" -> Ok Wasm
  | value ->
      Error
        ("Invalid runtime_kind in manifest: " ^ value
       ^ ". Expected one of: js, wasm")

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

let resolve_relative ~base_dir relative = normalize_path (Filename.concat base_dir relative)

let resolve_worker_runtime_with_framework_root ~framework_root relative =
  let marker = "worker_runtime/" in
  let rec find_marker start =
    if start + String.length marker > String.length relative then None
    else if String.sub relative start (String.length marker) = marker then Some start
    else find_marker (start + 1)
  in
  match find_marker 0 with
  | None -> None
  | Some idx ->
      let suffix = String.sub relative idx (String.length relative - idx) in
      Some (normalize_path (Filename.concat framework_root suffix))

let resolve_reference_from_base ~framework_root ~base_dir relative =
  let app_relative = resolve_relative ~base_dir relative in
  match resolve_worker_runtime_with_framework_root ~framework_root relative with
  | Some path when Sys.file_exists path -> path
  | _ when Sys.file_exists app_relative -> app_relative
  | _ -> app_relative

let resolve_reference ~framework_root ~manifest_path relative =
  resolve_reference_from_base ~framework_root
    ~base_dir:(Filename.dirname manifest_path) relative

let extract_value content key =
  let marker = Printf.sprintf "\"%s\"" key in
  match String.index_from_opt content 0 marker.[0] with
  | None -> None
  | Some _ ->
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
      (match find_marker 0 with
      | None -> None
      | Some marker_idx ->
          let after_marker = marker_idx + String.length marker in
          match String.index_from_opt content after_marker ':' with
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
              else
                let rec find_end idx =
                  if idx >= String.length content then idx
                  else
                    match content.[idx] with
                    | ',' | '}' | '\n' | '\r' -> idx
                    | _ -> find_end (idx + 1)
                in
                Some (String.sub content value_idx (find_end value_idx - value_idx) |> trim))

let parse ~manifest_path =
  if not (Sys.file_exists manifest_path) then
    Error ("Missing manifest: " ^ manifest_path)
  else
    let content = read_file manifest_path in
    let find key = extract_value content key in
    match
      ( find "abi_version",
        find "app_id",
        find "runtime_kind",
        find "runtime_entry",
        find "app_abi",
        find "generated_wasm_assets",
        find "compiled_runtime_backend",
        find "bootstrap_module",
        find "compiled_runtime",
        find "assets_dir" )
    with
    | Some abi_version, Some app_id, Some runtime_kind, Some runtime_entry,
      Some app_abi, generated_wasm_assets, Some compiled_runtime_backend,
      bootstrap_module, Some compiled_runtime, assets_dir ->
        let abi_version =
          try int_of_string (strip_quotes abi_version)
          with Failure _ -> -1
        in
        if abi_version < 0 then Error ("Invalid abi_version in manifest: " ^ manifest_path)
        else
          let runtime_kind_value = strip_quotes runtime_kind in
          (match runtime_kind_of_string runtime_kind_value with
          | Error msg -> Error (msg ^ ": " ^ manifest_path)
          | Ok runtime_kind ->
              let generated_wasm_assets = Option.map strip_quotes generated_wasm_assets in
              let bootstrap_module = Option.map strip_quotes bootstrap_module in
              let assets_dir = Option.map strip_quotes assets_dir in
              let missing_for_runtime =
                match runtime_kind with
                | Js -> []
                | Wasm ->
                    [ (if Option.is_none generated_wasm_assets then [ "generated_wasm_assets" ] else []);
                      (if Option.is_none bootstrap_module then [ "bootstrap_module" ] else []);
                      (if Option.is_none assets_dir then [ "assets_dir" ] else []) ]
                    |> List.flatten
              in
              if missing_for_runtime <> [] then
                Error
                  ("Manifest is missing required fields for runtime_kind="
                 ^ runtime_kind_value ^ ": " ^ String.concat ", " missing_for_runtime
                 ^ " in " ^ manifest_path)
              else
                Ok
                  {
                    abi_version;
                    app_id = strip_quotes app_id;
                    runtime_kind;
                    runtime_entry = strip_quotes runtime_entry;
                    app_abi = strip_quotes app_abi;
                    generated_wasm_assets;
                    compiled_runtime_backend = strip_quotes compiled_runtime_backend;
                    bootstrap_module;
                    compiled_runtime = strip_quotes compiled_runtime;
                    assets_dir;
                  })
    | _ -> Error ("Manifest is missing required fields: " ^ manifest_path)

let referenced_paths ~framework_root ~manifest_path =
  match parse ~manifest_path with
  | Error e -> Error e
  | Ok manifest ->
      let base_dir = Filename.dirname manifest_path in
      Ok
        ([ manifest_path;
           resolve_reference_from_base ~framework_root ~base_dir manifest.runtime_entry;
           resolve_reference_from_base ~framework_root ~base_dir manifest.app_abi;
           resolve_reference_from_base ~framework_root ~base_dir manifest.compiled_runtime_backend;
           resolve_reference_from_base ~framework_root ~base_dir manifest.compiled_runtime ]
        @ (match manifest.generated_wasm_assets with
          | Some path -> [ resolve_reference_from_base ~framework_root ~base_dir path ]
          | None -> [])
        @ (match manifest.bootstrap_module with
          | Some path -> [ resolve_reference_from_base ~framework_root ~base_dir path ]
          | None -> [])
        @ (match manifest.assets_dir with
          | Some path -> [ resolve_reference_from_base ~framework_root ~base_dir path ]
          | None -> []))
