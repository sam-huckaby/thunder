(** Parse Thunder app configuration files. *)

type compile_target = Js | Wasm

type cloudflare_mode = Dev_test

type cloudflare_named_binding = {
  binding : string;
  name : string;
}

type cloudflare_r2_binding = {
  binding : string;
  bucket : string;
}

type cloudflare_ai_binding = { binding : string }

type cloudflare_durable_object_binding = {
  binding : string;
  class_name : string;
}

type cloudflare_service_binding = {
  binding : string;
  service : string;
}

type cloudflare_resources = {
  kv : cloudflare_named_binding list;
  r2 : cloudflare_r2_binding list;
  d1 : cloudflare_named_binding list;
  queues : cloudflare_named_binding list;
  ai : cloudflare_ai_binding list;
  durable_objects : cloudflare_durable_object_binding list;
  services : cloudflare_service_binding list;
}

type cloudflare = {
  mode : cloudflare_mode option;
  bootstrap_worker : bool option;
  resources : cloudflare_resources;
}

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
  cloudflare : cloudflare option;
}

val empty : t
val default_path : unit -> string
val read : config_path:string -> (t, string) result
val read_if_exists : config_path:string -> t
