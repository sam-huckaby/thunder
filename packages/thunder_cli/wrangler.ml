type result = {
  status : Unix.process_status;
  stdout : string;
  stderr : string;
}

type preview_info = {
  version_id : string option;
  preview_url : string option;
}

type resource_ref = {
  name : string;
  identifier : string option;
}

let read_all ic =
  let buf = Buffer.create 256 in
  (try
     while true do
       Buffer.add_channel buf ic 1
     done
   with End_of_file -> ());
  Buffer.contents buf

let command_name = "npx"

let run ?workdir args =
  let full_args = Array.of_list (command_name :: "wrangler" :: args) in
  let stdout_r, stdout_w = Unix.pipe () in
  let stderr_r, stderr_w = Unix.pipe () in
  let original_cwd = Sys.getcwd () in
  (match workdir with Some dir -> Sys.chdir dir | None -> ());
  let pid =
    Fun.protect
      ~finally:(fun () ->
        match workdir with Some _ -> Sys.chdir original_cwd | None -> ())
      (fun () -> Unix.create_process command_name full_args Unix.stdin stdout_w stderr_w)
  in
  Unix.close stdout_w;
  Unix.close stderr_w;
  let out_ic = Unix.in_channel_of_descr stdout_r in
  let err_ic = Unix.in_channel_of_descr stderr_r in
  let out_text = read_all out_ic in
  let err_text = read_all err_ic in
  close_in_noerr out_ic;
  close_in_noerr err_ic;
  let _, status = Unix.waitpid [] pid in
  { status; stdout = out_text; stderr = err_text }

let available () =
  match run [ "--version" ] with
  | { status = Unix.WEXITED 0; _ } -> true
  | _ -> false

(* Wrangler 4.80.0 command-mode notes:
   - `whoami` should be treated as text-mode for compatibility
   - `d1 list` supports `--json`
   - KV/R2/Queues create/list flows should be treated as text-mode
   - `d1 create` should be treated as text-mode
*)

let whoami_args () = [ "whoami" ]

let kv_namespace_create_args ~name = [ "kv"; "namespace"; "create"; name ]
let kv_namespace_list_args () = [ "kv"; "namespace"; "list" ]
let r2_bucket_create_args ~name = [ "r2"; "bucket"; "create"; name ]
let r2_bucket_list_args () = [ "r2"; "bucket"; "list" ]
let d1_database_create_args ~name = [ "d1"; "create"; name ]
let d1_database_list_args () = [ "d1"; "list"; "--json" ]
let queue_create_args ~name = [ "queues"; "create"; name ]
let queue_list_args () = [ "queues"; "list" ]
let worker_list_args () = [ "deployments"; "list" ]

let whoami () = run (whoami_args ())

let kv_namespace_create ~name = run (kv_namespace_create_args ~name)
let kv_namespace_list () = run (kv_namespace_list_args ())
let r2_bucket_create ~name = run (r2_bucket_create_args ~name)
let r2_bucket_list () = run (r2_bucket_list_args ())
let d1_database_create ~name = run (d1_database_create_args ~name)
let d1_database_list () = run (d1_database_list_args ())
let queue_create ~name = run (queue_create_args ~name)
let queue_list () = run (queue_list_args ())
let worker_list () = run (worker_list_args ())

let preview_upload ~workdir ~config_path ~runtime_path =
  run ?workdir
    ([ "--config"; config_path; "versions"; "upload" ]
    @ match runtime_path with Some path -> [ path ] | None -> [])

let deploy_prod ~workdir ~config_path ~runtime_path =
  run ?workdir
    ([ "--config"; config_path; "deploy" ]
    @ match runtime_path with Some path -> [ path ] | None -> [])

let trim_token token =
  let is_trim_char = function
    | ' ' | '\t' | '\n' | '\r' | '"' | '\'' | '(' | ')' | '[' | ']' | ',' | ';'
    | '.' -> true
    | _ -> false
  in
  let len = String.length token in
  let rec left i = if i < len && is_trim_char token.[i] then left (i + 1) else i in
  let rec right i = if i >= 0 && is_trim_char token.[i] then right (i - 1) else i in
  let l = left 0 in
  let r = right (len - 1) in
  if r < l then "" else String.sub token l (r - l + 1)

let find_preview_url text =
  text
  |> String.split_on_char '\n'
  |> List.find_map (fun line ->
         line
         |> String.split_on_char ' '
         |> List.map trim_token
         |> List.find_opt (fun token ->
                String.length token > 8
                && (String.starts_with ~prefix:"https://" token
                   || String.starts_with ~prefix:"http://" token)
                && String.contains token '.'))

let normalize_lower s = String.lowercase_ascii (String.trim s)

let merged_output ~stdout ~stderr = String.trim (stdout ^ "\n" ^ stderr)

let extract_json_payload ~stdout ~stderr =
  let text = merged_output ~stdout ~stderr in
  let len = String.length text in
  let rec find_start index =
    if index >= len then None
    else
      match text.[index] with '{' | '[' -> Some index | _ -> find_start (index + 1)
  in
  let rec find_end index =
    if index < 0 then None
    else
      match text.[index] with '}' | ']' -> Some index | _ -> find_end (index - 1)
  in
  match (find_start 0, find_end (len - 1)) with
  | Some start_idx, Some end_idx when end_idx >= start_idx ->
      Ok (String.sub text start_idx (end_idx - start_idx + 1))
  | _ -> Error "No JSON payload found in Wrangler output"

let contains_substring haystack needle =
  let hay_len = String.length haystack in
  let needle_len = String.length needle in
  let rec loop index =
    if needle_len = 0 then true
    else if index + needle_len > hay_len then false
    else if String.sub haystack index needle_len = needle then true
    else loop (index + 1)
  in
  loop 0

let split_on_substring text needle =
  let needle_len = String.length needle in
  let text_len = String.length text in
  let rec loop start index acc =
    if index + needle_len > text_len then
      List.rev (String.sub text start (text_len - start) :: acc)
    else if String.sub text index needle_len = needle then
      let part = String.sub text start (index - start) in
      loop (index + needle_len) (index + needle_len) (part :: acc)
    else loop start (index + 1) acc
  in
  if needle_len = 0 then [ text ] else loop 0 0 []

let split_table_columns line =
  if contains_substring line "│" then
    line |> split_on_substring "│" |> List.map String.trim
    |> List.filter (fun item -> item <> "")
  else if String.contains line '|' then
    line |> String.split_on_char '|' |> List.map String.trim
    |> List.filter (fun item -> item <> "")
  else []

let looks_like_separator line =
  String.for_all (function '-' | '+' | '|' | ' ' -> true | _ -> false) line

let parse_table_resource_refs text =
  text
  |> String.split_on_char '\n'
  |> List.filter_map (fun line ->
         let trimmed = String.trim line in
         if trimmed = "" || looks_like_separator trimmed then None
         else
           match split_table_columns trimmed with
           | [ name; id ] when name <> "title" && name <> "name" && name <> "bucket_name" && name <> "queue_name" && name <> "database_name" ->
               Some { name; identifier = Some id }
           | [ name ] when name <> "title" && name <> "name" && name <> "bucket_name" && name <> "queue_name" && name <> "database_name" ->
               Some { name; identifier = None }
            | _ -> None)

let parse_queue_table_refs text =
  text
  |> String.split_on_char '\n'
  |> List.filter_map (fun line ->
         let trimmed = String.trim line in
         if trimmed = "" || looks_like_separator trimmed then None
         else
           match split_table_columns trimmed with
           | id :: name :: _ when id <> "id" && name <> "name" -> Some { name; identifier = Some id }
           | _ ->
               let normalized =
                 if contains_substring trimmed "│" then String.concat " " (split_on_substring trimmed "│")
                 else trimmed
               in
               let tokens =
                 normalized |> String.split_on_char ' ' |> List.map trim_token
                 |> List.filter (fun item -> item <> "")
               in
               (match tokens with
               | id :: name :: _ when id <> "id" && name <> "name" && String.length id >= 8 ->
                   Some { name; identifier = Some id }
               | _ -> None))

let token_candidates text =
  text
  |> String.split_on_char '\n'
  |> List.concat_map (fun line -> String.split_on_char ' ' line)
  |> List.map trim_token
  |> List.filter (fun token -> token <> "")

let find_identifier_in_text text =
  let tokens = token_candidates text in
  let has_digit s = String.exists (fun c -> c >= '0' && c <= '9') s in
  tokens
  |> List.find_opt (fun token ->
         String.length token >= 8
         && has_digit token
         && String.exists (fun c -> c = '-' || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F') || (c >= '0' && c <= '9')) token)

let rec find_string_field keys = function
  | Simple_json.Object fields ->
      let direct =
        keys
        |> List.find_map (fun key ->
               match List.assoc_opt key fields with Some (Simple_json.String value) -> Some value | _ -> None)
      in
      (match direct with Some _ as value -> value | None -> fields |> List.find_map (fun (_, value) -> find_string_field keys value))
  | Simple_json.Array values -> List.find_map (find_string_field keys) values
  | _ -> None

let resource_name_of_json value =
  find_string_field [ "title"; "name"; "bucket_name"; "queue_name"; "database_name"; "script_name" ] value

let resource_id_of_json value =
  find_string_field [ "id"; "namespace_id"; "database_id"; "uuid" ] value

let rec collect_resource_refs = function
  | Simple_json.Array values ->
      values
      |> List.filter_map (fun value ->
             match resource_name_of_json value with
             | Some name -> Some { name; identifier = resource_id_of_json value }
             | None -> None)
  | Simple_json.Object fields as value ->
      (match List.assoc_opt "result" fields with
      | Some result -> collect_resource_refs result
      | None ->
          (match resource_name_of_json value with
          | Some name -> [ { name; identifier = resource_id_of_json value } ]
      | None -> []))
  | _ -> []

let parse_create_result ~kind:_ ~name ~stdout ~stderr =
  let text = merged_output ~stdout ~stderr in
  match extract_json_payload ~stdout ~stderr with
  | Ok payload ->
      (match Simple_json.parse payload with
      | Ok json ->
          let refs = collect_resource_refs json in
          (match refs with
          | resource :: _ -> Ok resource
          | [] -> Ok { name; identifier = find_identifier_in_text text })
      | Error _ -> Ok { name; identifier = find_identifier_in_text text })
  | Error _ -> Ok { name; identifier = find_identifier_in_text text }

let parse_list_result ~kind:_ ~stdout ~stderr =
  let text = merged_output ~stdout ~stderr in
  match extract_json_payload ~stdout ~stderr with
  | Ok payload ->
      (match Simple_json.parse payload with
      | Ok json -> Ok (collect_resource_refs json)
      | Error _ ->
          let refs = parse_table_resource_refs text in
          if refs = [] then Error "Unable to parse Wrangler text output for resource list" else Ok refs)
  | Error _ ->
      let refs = parse_table_resource_refs text in
      if refs = [] then Error "Unable to parse Wrangler text output for resource list" else Ok refs

let parse_account_id ~stdout ~stderr =
  let text = merged_output ~stdout ~stderr in
  match extract_json_payload ~stdout ~stderr with
  | Ok payload ->
      (match Simple_json.parse payload with
      | Ok json -> find_string_field [ "account_id"; "accountId"; "id" ] json
      | Error _ -> None)
  | Error _ ->
      let lines = String.split_on_char '\n' text in
      lines
      |> List.find_map (fun line ->
             let lower = normalize_lower line in
             if contains_substring lower "account id" && String.contains line ':' then
                match List.rev (String.split_on_char ':' line) with
                | value :: _ ->
                    let trimmed = String.trim value in
                    if trimmed = "" then None else Some trimmed
                | [] -> None
             else None)

let parse_resource_refs ~stdout ~stderr =
  parse_list_result ~kind:"resource" ~stdout ~stderr

let parse_kv_namespace_create ~name ~stdout ~stderr =
  parse_create_result ~kind:"kv" ~name ~stdout ~stderr

let parse_kv_namespace_list ~stdout ~stderr = parse_list_result ~kind:"kv" ~stdout ~stderr

let parse_r2_bucket_create ~name ~stdout ~stderr =
  parse_create_result ~kind:"r2" ~name ~stdout ~stderr

let parse_r2_bucket_list ~stdout ~stderr = parse_list_result ~kind:"r2" ~stdout ~stderr

let parse_d1_database_create ~name ~stdout ~stderr =
  parse_create_result ~kind:"d1" ~name ~stdout ~stderr

let parse_queue_create ~name ~stdout ~stderr =
  parse_create_result ~kind:"queue" ~name ~stdout ~stderr

let parse_queue_list ~stdout ~stderr =
  let text = merged_output ~stdout ~stderr in
  match extract_json_payload ~stdout ~stderr with
  | Ok payload ->
      (match Simple_json.parse payload with
      | Ok json -> Ok (collect_resource_refs json)
      | Error _ ->
          let refs = parse_queue_table_refs text in
          if refs = [] then Error "Unable to parse Wrangler text output for queue list" else Ok refs)
  | Error _ ->
      let refs = parse_queue_table_refs text in
      if refs = [] then Error "Unable to parse Wrangler text output for queue list" else Ok refs

let worker_exists ~worker_name ~stdout ~stderr =
  let text = merged_output ~stdout ~stderr in
  if contains_substring (normalize_lower text) "no deployments found" then Ok false
  else if text = "" then Ok false
  else if contains_substring text worker_name then Ok true
  else Ok true

let find_version_id text =
  text
  |> String.split_on_char '\n'
  |> List.find_map (fun line ->
         let trimmed = String.trim line in
         let prefixes = [ "Worker Version ID:"; "Version ID:" ] in
         prefixes
         |> List.find_map (fun prefix ->
                if String.starts_with ~prefix trimmed then
                  let value =
                    String.trim
                      (String.sub trimmed (String.length prefix)
                         (String.length trimmed - String.length prefix))
                  in
                  if value = "" then None else Some value
                else None))

let parse_preview_info ~stdout ~stderr =
  let merged = stdout ^ "\n" ^ stderr in
  { version_id = find_version_id merged; preview_url = find_preview_url merged }
