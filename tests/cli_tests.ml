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
      let hash =
        match Thunder_cli_lib.Artifact_hash.compute [ artifact ] with
        | Ok value -> value
        | Error e -> failwith e
      in
      with_temp_path "thunder-preview" (fun metadata_path ->
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
                artifacts = [ artifact ];
                force = false;
              }
          with
          | Ok msg -> assert_true "skip unchanged" (String.length msg > 0)
          | Error err -> failwith err));
  print_endline "cli_tests: ok"
