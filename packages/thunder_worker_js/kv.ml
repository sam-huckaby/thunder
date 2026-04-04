let get_text ~binding ~key req =
  match Worker.request_id req with
  | Some request_id -> Binding_rpc.get_text ~request_id ~binding ~key
  | None -> Async.fail (Binding_rpc.Error "Thunder KV access requires a request id in context.")

let get_bytes ~binding ~key req =
  match Worker.request_id req with
  | Some request_id -> Binding_rpc.get_bytes ~request_id ~binding ~key
  | None -> Async.fail (Binding_rpc.Error "Thunder KV access requires a request id in context.")

let put_text ~binding ~key ~value req =
  match Worker.request_id req with
  | Some request_id -> Binding_rpc.put_text ~request_id ~binding ~key ~value
  | None -> Async.fail (Binding_rpc.Error "Thunder KV access requires a request id in context.")

let put_bytes ~binding ~key ~value req =
  match Worker.request_id req with
  | Some request_id -> Binding_rpc.put_bytes ~request_id ~binding ~key ~value
  | None -> Async.fail (Binding_rpc.Error "Thunder KV access requires a request id in context.")

let delete ~binding ~key req =
  match Worker.request_id req with
  | Some request_id -> Binding_rpc.delete ~request_id ~binding ~key
  | None -> Async.fail (Binding_rpc.Error "Thunder KV access requires a request id in context.")
