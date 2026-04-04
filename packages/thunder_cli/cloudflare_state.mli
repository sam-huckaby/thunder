type managed_resource = {
  kind : string;
  binding : string;
  name : string option;
  identifier : string option;
  managed : bool;
}

type worker_bootstrap = {
  script_name : string option;
  bootstrapped : bool;
  last_deploy_at : string option;
}

type t = {
  account_id : string option;
  worker : worker_bootstrap option;
  resources : managed_resource list;
  last_provision_at : string option;
  last_status_at : string option;
}

val empty : t
val default_path : unit -> string
val read : path:string -> (t, string) result
val read_if_exists : path:string -> t
val write : path:string -> t -> (unit, string) result
