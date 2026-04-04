type worker = {
  name : string option;
  configured : bool;
  bootstrapped : bool;
  remote_exists : bool;
}

type resource = {
  kind : string;
  binding : string;
  name : string option;
  managed : bool;
  configured : bool;
  state_present : bool;
  remote_exists : bool;
  healthy : bool;
}

type t = {
  ok : bool;
  mode : string;
  account_id : string option;
  worker : worker;
  resources : resource list;
  warnings : string list;
  errors : string list;
}

type ops = {
  account_id : unit -> (string option, string) result;
  kv_resources : unit -> (Wrangler.resource_ref list, string) result;
  r2_resources : unit -> (Wrangler.resource_ref list, string) result;
  d1_resources : unit -> (Wrangler.resource_ref list, string) result;
  queue_resources : unit -> (Wrangler.resource_ref list, string) result;
  worker_exists : string -> (bool, string) result;
}

val empty : t
val to_json : t -> Simple_json.value
val default_ops : ops
val render_pretty : t -> string
val run : ops:ops -> Thunder_config.t -> Cloudflare_state.t -> t
