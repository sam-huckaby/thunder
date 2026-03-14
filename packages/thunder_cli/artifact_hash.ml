let slurp path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let rec collect_files path =
  if Sys.file_exists path then
    if Sys.is_directory path then
      Sys.readdir path
      |> Array.to_list
      |> List.sort String.compare
      |> List.concat_map (fun entry -> collect_files (Filename.concat path entry))
    else [ path ]
  else []

let compute artifacts =
  let sorted =
    artifacts |> List.sort String.compare |> List.concat_map collect_files
    |> List.sort String.compare
  in
  try
    let digest = Digest.string "" in
    let combined =
      List.fold_left
        (fun acc path ->
          if Sys.file_exists path then
            Digest.string (acc ^ path ^ ":" ^ slurp path) |> Digest.to_hex
          else raise (Failure ("missing artifact: " ^ path)))
        (Digest.to_hex digest) sorted
    in
    Ok combined
  with Failure msg -> Error msg

let compute_with_manifest ?(framework_root = ".") ~manifest_path artifacts =
  match Deploy_manifest.referenced_paths ~framework_root ~manifest_path with
  | Error e -> Error e
  | Ok manifest_artifacts -> compute (manifest_artifacts @ artifacts)

let read_previous_hash ~metadata_path =
  if not (Sys.file_exists metadata_path) then None
  else
    let content = slurp metadata_path in
    let lines = String.split_on_char '\n' content in
    lines
    |> List.find_map (fun line ->
           match String.split_on_char '=' line with
           | [ "hash"; value ] -> Some value
           | [ "artifact_hash"; value ] -> Some value
           | _ -> None)

let ensure_parent_dir path =
  let dir = Filename.dirname path in
  if dir <> "." && not (Sys.file_exists dir) then Unix.mkdir dir 0o755

let write_hash ~metadata_path ~hash =
  ensure_parent_dir metadata_path;
  let oc = open_out metadata_path in
  Fun.protect
    ~finally:(fun () -> close_out_noerr oc)
    (fun () -> output_string oc ("artifact_hash=" ^ hash ^ "\n"))
