(** Explicit production deploy orchestration. *)

val run :
  artifacts:string list ->
  deploy_dir:string ->
  wrangler_template_path:string ->
  runtime_path:string ->
  compiled_runtime_path:string ->
  (string, string) result
