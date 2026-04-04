type provision_ops = {
  account_id : unit -> (string option, string) result;
  provision : Cloudflare_provision.ops;
  build_worker : unit -> (unit, string) result;
  bootstrap : Cloudflare_bootstrap.ops;
}

val default_provision_ops : provision_ops
val run_provision_with : debug:bool -> ops:provision_ops -> config_path:string -> (string, string) result
val run_provision : debug:bool -> config_path:string -> (string, string) result
