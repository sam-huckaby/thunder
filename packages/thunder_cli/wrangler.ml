type result = {
  status : Unix.process_status;
  stdout : string;
  stderr : string;
}

type preview_info = {
  version_id : string option;
  preview_url : string option;
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

let run args =
  let full_args = Array.of_list (command_name :: "wrangler" :: args) in
  let stdout_r, stdout_w = Unix.pipe () in
  let stderr_r, stderr_w = Unix.pipe () in
  let pid =
    Unix.create_process command_name full_args Unix.stdin stdout_w stderr_w
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

let preview_upload ~config_path =
  run [ "--config"; config_path; "versions"; "upload" ]

let deploy_prod ~config_path = run [ "--config"; config_path; "deploy" ]

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

let find_version_id text =
  let lines = String.split_on_char '\n' text in
  let parse_line line =
    let lower = normalize_lower line in
    if String.contains lower 'v' then
      if String.contains lower ':' then
        let parts = String.split_on_char ':' line in
        match List.rev parts with
        | [] -> None
        | value :: _ ->
            let v = String.trim value in
            if v = "" then None else Some v
      else
        line
        |> String.split_on_char ' '
        |> List.map String.trim
        |> List.filter (fun x -> x <> "")
        |> List.rev
        |> function [] -> None | value :: _ -> Some value
    else None
  in
  lines
  |> List.find_map (fun line ->
         let lower = normalize_lower line in
         if String.contains lower 'v' && String.contains lower 'i' then parse_line line
         else None)

let parse_preview_info ~stdout ~stderr =
  let merged = stdout ^ "\n" ^ stderr in
  { version_id = find_version_id merged; preview_url = find_preview_url merged }
