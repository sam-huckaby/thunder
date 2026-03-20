type compile_target = Js | Wasm

type t = {
  compile_target : compile_target;
  compiled_runtime_path : string;
  manifest_path : string;
  assets_dir : string option;
  wrangler_template_path : string;
  deploy_dir : string;
  framework_root : string;
}

let compile_target_of_config = function
  | Thunder_config.Js -> Js
  | Thunder_config.Wasm -> Wasm

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

let file_exists path =
  try Sys.file_exists path with _ -> false

let config_path () = Thunder_config.default_path ()

let is_framework_root path =
  file_exists (Filename.concat path "dune-project")
  && file_exists (Filename.concat path "packages/thunder_cli/main.ml")
  && file_exists (Filename.concat path "worker_runtime/index.mjs")
  && file_exists (Filename.concat path "worker_runtime/app_abi.mjs")

let rec ancestors path =
  let path = normalize_path path in
  let parent = Filename.dirname path in
  if parent = path then [ path ] else path :: ancestors parent

let first_matching_root candidates =
  candidates |> List.find_opt is_framework_root

let executable_candidates () =
  let argv0 = Sys.argv.(0) in
  let path =
    if Filename.is_relative argv0 then Filename.concat (Sys.getcwd ()) argv0 else argv0
  in
  ancestors (Filename.dirname path)

let cwd_candidates () = ancestors (Sys.getcwd ())

let opam_candidates () =
  match Sys.getenv_opt "OPAM_SWITCH_PREFIX" with
  | None -> []
  | Some prefix ->
      [ Filename.concat prefix "share/thunder";
        Filename.concat prefix "share/thunder-cloudflare" ]

let installed_home_candidates () =
  let current = Framework_home.current_dir () in
  let versioned =
    match Sys.getenv_opt "THUNDER_VERSION" with
    | None -> []
    | Some version -> [ Framework_home.versioned_dir ~version ]
  in
  current :: versioned

let discover_framework_root () =
  match Sys.getenv_opt "THUNDER_FRAMEWORK_ROOT" with
  | Some path when is_framework_root path -> path
  | _ ->
      let candidates =
        installed_home_candidates () @ cwd_candidates () @ executable_candidates ()
        @ opam_candidates ()
      in
      Option.value (first_matching_root candidates) ~default:"."

let derive compile_target compiled_runtime_path manifest_path wrangler_template_path deploy_dir
    framework_root =
  let dist_dir = Filename.dirname compiled_runtime_path in
  {
    compile_target;
    compiled_runtime_path;
    manifest_path = Option.value manifest_path ~default:(Filename.concat dist_dir "manifest.json");
    assets_dir =
      (match compile_target with
      | Js -> None
      | Wasm -> Some (Filename.concat dist_dir "thunder_runtime.assets"));
    wrangler_template_path;
    deploy_dir;
    framework_root;
  }

let default_result () =
  let config_path = config_path () in
  let config =
    if Sys.file_exists config_path then Thunder_config.read ~config_path else Ok Thunder_config.empty
  in
  match config with
  | Error msg -> Error msg
  | Ok config ->
      let discovered_framework_root = discover_framework_root () in
      Ok
        (derive
           (Option.value config.compile_target ~default:Thunder_config.Js |> compile_target_of_config)
           (Option.value config.compiled_runtime_path ~default:"dist/worker/thunder_runtime.mjs")
           None
           (Option.value config.wrangler_template_path ~default:"wrangler.toml")
           (Option.value config.deploy_dir ~default:"deploy")
           (Option.value (Sys.getenv_opt "THUNDER_FRAMEWORK_ROOT")
              ~default:(Option.value config.framework_root ~default:discovered_framework_root)))

let default () =
  match default_result () with Ok layout -> layout | Error msg -> failwith msg

let with_overrides_result ?compile_target ?compiled_runtime_path ?manifest_path
    ?wrangler_template_path ?deploy_dir ?framework_root () =
  match default_result () with
  | Error msg -> Error msg
  | Ok base ->
      Ok
        (derive
           (Option.value compile_target ~default:base.compile_target)
           (Option.value compiled_runtime_path ~default:base.compiled_runtime_path)
           (match manifest_path with None -> Some base.manifest_path | Some _ as value -> value)
           (Option.value wrangler_template_path ~default:base.wrangler_template_path)
           (Option.value deploy_dir ~default:base.deploy_dir)
           (Option.value framework_root ~default:base.framework_root))

let with_overrides ?compile_target ?compiled_runtime_path ?manifest_path
    ?wrangler_template_path ?deploy_dir ?framework_root () =
  match
    with_overrides_result ?compile_target ?compiled_runtime_path ?manifest_path
      ?wrangler_template_path ?deploy_dir ?framework_root ()
  with
  | Ok layout -> layout
  | Error msg -> failwith msg
