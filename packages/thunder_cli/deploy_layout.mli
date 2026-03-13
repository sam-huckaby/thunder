(** Build and stage a deploy-ready Worker tree. *)

type staged = {
  deploy_dir : string;
  config_path : string;
  runtime_path : string;
  bootstrap_path : string;
  compiled_runtime_path : string;
  assets_dir : string;
}

val stage :
  deploy_dir:string ->
  wrangler_template_path:string ->
  runtime_path:string ->
  compiled_runtime_path:string ->
  (staged, string) result
