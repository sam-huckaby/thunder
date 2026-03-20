(** Parse Thunder app configuration files. *)

type compile_target = Js | Wasm

val compile_target_of_string : string -> (compile_target, string) result
val compile_target_to_string : compile_target -> string

type t = {
  compile_target : compile_target option;
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
