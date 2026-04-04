let require_request_id req =
  match Worker.request_id req with
  | Some request_id -> request_id
  | None ->
      raise (Binding_rpc.Error "Thunder Durable Object access requires a request id in context.")

let call_json ~binding ~name ~method_ ~args_json req =
  Binding_rpc.durable_object_call_json ~request_id:(require_request_id req) ~binding ~name
    ~method_ ~args_json
