type config = {
  metadata_path : string;
  artifacts : string list;
  force : bool;
}

type metadata = {
  artifact_hash : string option;
  last_upload_at : string option;
  last_version_id : string option;
  last_preview_url : string option;
  raw_wrangler_output : string option;
}

let empty_metadata =
  {
    artifact_hash = None;
    last_upload_at = None;
    last_version_id = None;
    last_preview_url = None;
    raw_wrangler_output = None;
  }

let missing_artifacts artifacts =
  artifacts |> List.filter (fun path -> not (Sys.file_exists path))

let string_of_status = function
  | Unix.WEXITED code -> "exit(" ^ string_of_int code ^ ")"
  | Unix.WSIGNALED signal -> "signal(" ^ string_of_int signal ^ ")"
  | Unix.WSTOPPED signal -> "stopped(" ^ string_of_int signal ^ ")"

let now_iso8601 () =
  let tm = Unix.gmtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.Unix.tm_year + 1900)
    (tm.Unix.tm_mon + 1) tm.Unix.tm_mday tm.Unix.tm_hour tm.Unix.tm_min
    tm.Unix.tm_sec

let truncate_output text =
  let max_len = 2000 in
  if String.length text <= max_len then text
  else String.sub text 0 max_len ^ "...<truncated>"

let ensure_parent_dir path =
  let dir = Filename.dirname path in
  if dir <> "." && not (Sys.file_exists dir) then Unix.mkdir dir 0o755

let parse_metadata_line metadata line =
  match String.split_on_char '=' line with
  | [ "hash"; value ] -> { metadata with artifact_hash = Some value }
  | [ "artifact_hash"; value ] -> { metadata with artifact_hash = Some value }
  | [ "last_upload_at"; value ] -> { metadata with last_upload_at = Some value }
  | [ "last_version_id"; value ] -> { metadata with last_version_id = Some value }
  | [ "last_preview_url"; value ] -> { metadata with last_preview_url = Some value }
  | "raw_wrangler_output" :: rest ->
      { metadata with raw_wrangler_output = Some (String.concat "=" rest) }
  | _ -> metadata

let read_metadata ~metadata_path =
  if not (Sys.file_exists metadata_path) then empty_metadata
  else
    let ic = open_in metadata_path in
    Fun.protect
      ~finally:(fun () -> close_in_noerr ic)
      (fun () ->
        let rec loop acc =
          match input_line ic with
          | line -> loop (parse_metadata_line acc line)
          | exception End_of_file -> acc
        in
        loop empty_metadata)

let write_metadata ~metadata_path metadata =
  ensure_parent_dir metadata_path;
  let oc = open_out metadata_path in
  let write_opt key value_opt =
    match value_opt with
    | None -> ()
    | Some value -> output_string oc (key ^ "=" ^ value ^ "\n")
  in
  Fun.protect
    ~finally:(fun () -> close_out_noerr oc)
    (fun () ->
      write_opt "artifact_hash" metadata.artifact_hash;
      write_opt "last_upload_at" metadata.last_upload_at;
      write_opt "last_version_id" metadata.last_version_id;
      write_opt "last_preview_url" metadata.last_preview_url;
      write_opt "raw_wrangler_output" metadata.raw_wrangler_output)

let make_success_message (info : Wrangler.preview_info) =
  match (info.version_id, info.preview_url) with
  | Some version_id, Some preview_url ->
      "Preview uploaded. version_id=" ^ version_id ^ " preview_url=" ^ preview_url
  | Some version_id, None ->
      "Preview uploaded. version_id=" ^ version_id
      ^ " (preview URL not found in Wrangler output)."
  | None, Some preview_url ->
      "Preview uploaded. preview_url=" ^ preview_url
      ^ " (version id not found in Wrangler output)."
  | None, None ->
      "Preview uploaded. Could not parse version id or preview URL from Wrangler output."

let run config =
  let missing = missing_artifacts config.artifacts in
  if missing <> [] then
    Error
      ("Missing artifact(s): " ^ String.concat ", " missing
     ^ ". Run dune build @worker-build first.")
  else
    match Artifact_hash.compute config.artifacts with
    | Error e -> Error e
    | Ok hash ->
        let metadata = read_metadata ~metadata_path:config.metadata_path in
        let changed =
          match metadata.artifact_hash with
          | None -> true
          | Some old_hash -> old_hash <> hash
        in
        if (not changed) && not config.force then
          Ok "Preview publish skipped (artifact hash unchanged)."
        else if Sys.getenv_opt "CLOUDFLARE_API_TOKEN" = None then
          Ok
            "Preview publish skipped (CLOUDFLARE_API_TOKEN is not set in this environment)."
        else if not (Wrangler.available ()) then
          Ok "Preview publish skipped (Wrangler not available in this environment)."
        else
          let result = Wrangler.preview_upload () in
          match result.status with
          | Unix.WEXITED 0 ->
              let info = Wrangler.parse_preview_info ~stdout:result.stdout ~stderr:result.stderr in
              let raw_output = truncate_output (String.trim (result.stdout ^ "\n" ^ result.stderr)) in
              let updated =
                {
                  artifact_hash = Some hash;
                  last_upload_at = Some (now_iso8601 ());
                  last_version_id = info.version_id;
                  last_preview_url = info.preview_url;
                  raw_wrangler_output = Some raw_output;
                }
              in
              write_metadata ~metadata_path:config.metadata_path updated;
              Ok (make_success_message info)
          | status ->
              Error
                ("Wrangler preview upload failed: " ^ string_of_status status ^ "\n"
               ^ result.stderr)
