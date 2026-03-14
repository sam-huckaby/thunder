let has_command command =
  Sys.command ("command -v " ^ command ^ " >/dev/null 2>&1") = 0

let status_line label ok value =
  let state = if ok then "ok" else "missing" in
  "- " ^ label ^ ": " ^ state ^ (if value = "" then "" else " (" ^ value ^ ")")

let run () =
  let framework_root = Project_layout.discover_framework_root () in
  let thunder_config = Thunder_config.read_if_exists ~config_path:(Project_layout.config_path ()) in
  let current_home = Framework_home.current_dir () in
  let lines =
    [ "Thunder doctor";
      status_line "thunder config"
        (Sys.file_exists (Project_layout.config_path ())) (Project_layout.config_path ());
      status_line "framework root"
        (Sys.file_exists (Filename.concat framework_root "packages/thunder_cli/main.ml"))
        framework_root;
      status_line "installed framework home"
        (Sys.file_exists current_home) current_home;
      status_line "dune" (has_command "dune") "dune";
      status_line "npm" (has_command "npm") "npm";
      status_line "python3" (has_command "python3") "python3";
      status_line "wrangler" (has_command "npx") "npx";
      status_line "configured app module"
        (Option.is_some thunder_config.app_module)
        (Option.value thunder_config.app_module ~default:"unset");
      status_line "configured worker entry"
        (Option.is_some thunder_config.worker_entry_path)
        (Option.value thunder_config.worker_entry_path ~default:"unset");
    ]
  in
  Ok (String.concat "\n" lines)
