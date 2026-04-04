type env = (string * string) list
type ctx = string list
type raw = unit

let env_key : env Thunder_core.Context.key = Thunder_core.Context.key ()
let ctx_key : ctx Thunder_core.Context.key = Thunder_core.Context.key ()
let request_id_key : string option Thunder_core.Context.key = Thunder_core.Context.key ()
let raw_env_key : raw option Thunder_core.Context.key = Thunder_core.Context.key ()
let raw_ctx_key : raw option Thunder_core.Context.key = Thunder_core.Context.key ()

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

let with_request_id req request_id =
  let updated = Thunder_core.Context.add (Request.context_map req) request_id_key request_id in
  Request.with_context req updated

let with_raw_env req request_id =
  let updated_ctx =
    let _ = request_id in
    Thunder_core.Context.add (Request.context_map req) raw_env_key None
  in
  Request.with_context req updated_ctx

let with_raw_ctx req request_id =
  let updated_ctx =
    let _ = request_id in
    Thunder_core.Context.add (Request.context_map req) raw_ctx_key None
  in
  Request.with_context req updated_ctx

let env req =
  match Request.context req env_key with
  | Some v -> v
  | None -> []

let ctx req =
  match Request.context req ctx_key with
  | Some v -> v
  | None -> []

let request_id req = Option.join (Request.context req request_id_key)

let raw_env req = Option.join (Request.context req raw_env_key)

let raw_ctx req = Option.join (Request.context req raw_ctx_key)

let binding_any req name =
  match raw_env req with
  | None ->
      let _ = name in
      None
  | Some _ -> None
