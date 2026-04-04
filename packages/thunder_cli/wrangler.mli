(** Thin wrapper around Wrangler command invocation. *)

type result = {
  status : Unix.process_status;
  stdout : string;
  stderr : string;
}

type preview_info = {
  version_id : string option;
  preview_url : string option;
}

type resource_ref = {
  name : string;
  identifier : string option;
}

val whoami_args : unit -> string list
val kv_namespace_create_args : name:string -> string list
val kv_namespace_list_args : unit -> string list
val r2_bucket_create_args : name:string -> string list
val r2_bucket_list_args : unit -> string list
val d1_database_create_args : name:string -> string list
val d1_database_list_args : unit -> string list
val queue_create_args : name:string -> string list
val queue_list_args : unit -> string list
val worker_list_args : unit -> string list
val run : ?workdir:string -> string list -> result
val whoami : unit -> result
val kv_namespace_create : name:string -> result
val kv_namespace_list : unit -> result
val r2_bucket_create : name:string -> result
val r2_bucket_list : unit -> result
val d1_database_create : name:string -> result
val d1_database_list : unit -> result
val queue_create : name:string -> result
val queue_list : unit -> result
val worker_list : unit -> result
val preview_upload : workdir:string option -> config_path:string -> runtime_path:string option -> result
val deploy_prod : workdir:string option -> config_path:string -> runtime_path:string option -> result
val available : unit -> bool
val parse_account_id : stdout:string -> stderr:string -> string option
val extract_json_payload : stdout:string -> stderr:string -> (string, string) Stdlib.result
val parse_kv_namespace_create : name:string -> stdout:string -> stderr:string -> (resource_ref, string) Stdlib.result
val parse_kv_namespace_list : stdout:string -> stderr:string -> (resource_ref list, string) Stdlib.result
val parse_r2_bucket_create : name:string -> stdout:string -> stderr:string -> (resource_ref, string) Stdlib.result
val parse_r2_bucket_list : stdout:string -> stderr:string -> (resource_ref list, string) Stdlib.result
val parse_d1_database_create : name:string -> stdout:string -> stderr:string -> (resource_ref, string) Stdlib.result
val parse_queue_create : name:string -> stdout:string -> stderr:string -> (resource_ref, string) Stdlib.result
val parse_queue_list : stdout:string -> stderr:string -> (resource_ref list, string) Stdlib.result
val parse_resource_refs : stdout:string -> stderr:string -> (resource_ref list, string) Stdlib.result
val worker_exists : worker_name:string -> stdout:string -> stderr:string -> (bool, string) Stdlib.result
val parse_preview_info : stdout:string -> stderr:string -> preview_info
