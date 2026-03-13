type env = (string * string) list
type ctx = string list

let env_key : env Thunder_core.Context.key = Thunder_core.Context.key ()
let ctx_key : ctx Thunder_core.Context.key = Thunder_core.Context.key ()

let create_env bindings = bindings
let create_ctx values = values

let env_binding env key = env |> List.find_opt (fun (k, _) -> k = key) |> Option.map snd
let ctx_has_feature ctx feature = List.exists (( = ) feature) ctx

let with_env req env =
  let updated_ctx = Thunder_core.Context.add (Request.context_map req) env_key env in
  Request.with_context req updated_ctx

let with_ctx req worker_ctx =
  let updated = Thunder_core.Context.add (Request.context_map req) ctx_key worker_ctx in
  Request.with_context req updated

let env req =
  match Request.context req env_key with
  | Some v -> v
  | None -> []

let ctx req =
  match Request.context req ctx_key with
  | Some v -> v
  | None -> []
