type action = Create | Reuse | Adopt | Wire

type step = {
  kind : string;
  binding : string;
  name : string option;
  action : action;
}

type ops = {
  create_kv : name:string -> (Wrangler.resource_ref, string) result;
  list_kv : unit -> (Wrangler.resource_ref list, string) result;
  create_r2 : name:string -> (Wrangler.resource_ref, string) result;
  list_r2 : unit -> (Wrangler.resource_ref list, string) result;
  create_d1 : name:string -> (Wrangler.resource_ref, string) result;
  list_d1 : unit -> (Wrangler.resource_ref list, string) result;
  create_queue : name:string -> (Wrangler.resource_ref, string) result;
  list_queue : unit -> (Wrangler.resource_ref list, string) result;
}

val default_ops : ops

val run :
  ?account_id:string ->
  ?worker_name:string ->
  ?timestamp:string ->
  ?debug_log:(string -> unit) ->
  ops:ops ->
  Thunder_config.t ->
  Cloudflare_state.t ->
  ((Cloudflare_state.t * step list), string) result

val run_and_write :
  ?account_id:string ->
  ?worker_name:string ->
  ?timestamp:string ->
  ?debug_log:(string -> unit) ->
  ops:ops ->
  state_path:string ->
  Thunder_config.t ->
  Cloudflare_state.t ->
  ((Cloudflare_state.t * step list), string) result
