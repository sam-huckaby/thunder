type ops = { deploy_worker : workdir:string -> config_path:string -> runtime_path:string -> Wrangler.result }

val default_ops : ops

val run :
  ?timestamp:string ->
  ops:ops ->
  worker_name:string ->
  config_path:string ->
  state_path:string ->
  Cloudflare_state.t ->
  (Cloudflare_state.t, string) result
