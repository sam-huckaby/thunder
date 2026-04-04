let require_request_id req =
  match Worker.request_id req with
  | Some request_id -> request_id
  | None -> raise (Binding_rpc.Error "Thunder R2 access requires a request id in context.")

let get_text ~binding ~key req =
  Binding_rpc.r2_get_text ~request_id:(require_request_id req) ~binding ~key

let get_bytes ~binding ~key req =
  Binding_rpc.r2_get_bytes ~request_id:(require_request_id req) ~binding ~key

let put_text ~binding ~key ~value req =
  Binding_rpc.r2_put_text ~request_id:(require_request_id req) ~binding ~key ~value

let put_bytes ~binding ~key ~value req =
  Binding_rpc.r2_put_bytes ~request_id:(require_request_id req) ~binding ~key ~value
