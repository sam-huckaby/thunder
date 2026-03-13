(** Explicit production deploy orchestration. *)

val run :
  artifacts:string list ->
  deploy_dir:string ->
  wrangler_template_path:string ->
  manifest_path:string ->
  (string, string) result
