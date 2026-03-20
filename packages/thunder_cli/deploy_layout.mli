(** Build and stage a deploy-ready Worker tree. *)

type staged = {
  deploy_dir : string;
  config_path : string;
  runtime_path : string;
  app_abi_path : string;
  bootstrap_path : string option;
  compiled_runtime_path : string;
  manifest_path : string;
  assets_dir : string option;
}

val stage :
  deploy_dir:string ->
  wrangler_template_path:string ->
  manifest_path:string ->
  framework_root:string ->
  (staged, string) result
