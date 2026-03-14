(** Parse Thunder app configuration files. *)

type t = {
  app_module : string option;
  worker_entry_path : string option;
  compiled_runtime_path : string option;
  wrangler_template_path : string option;
  deploy_dir : string option;
  framework_root : string option;
}

val empty : t
val default_path : unit -> string
val read : config_path:string -> (t, string) result
val read_if_exists : config_path:string -> t
