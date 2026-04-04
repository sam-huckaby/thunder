val render_managed :
  config:Thunder_config.cloudflare ->
  state:Cloudflare_state.t ->
  template:string ->
  (string, string) result

val apply_to_file :
  config:Thunder_config.cloudflare ->
  state:Cloudflare_state.t ->
  path:string ->
  (string, string) result
