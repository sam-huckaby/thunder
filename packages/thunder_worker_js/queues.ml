let require_request_id req =
  match Worker.request_id req with
  | Some request_id -> request_id
  | None -> raise (Binding_rpc.Error "Thunder queue access requires a request id in context.")

let send_text ~binding ~value req =
  Binding_rpc.queue_send_text ~request_id:(require_request_id req) ~binding ~value

let send_bytes ~binding ~value req =
  Binding_rpc.queue_send_bytes ~request_id:(require_request_id req) ~binding ~value

let send_json ~binding ~value_json req =
  Binding_rpc.queue_send_json ~request_id:(require_request_id req) ~binding ~value_json

let send_batch_json ~binding ~messages_json req =
  Binding_rpc.queue_send_batch_json ~request_id:(require_request_id req) ~binding
    ~messages_json
