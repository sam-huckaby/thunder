let invoke_json ~binding ~method_ ~args_json req =
  match Worker.request_id req with
  | Some request_id -> Binding_rpc.invoke_json ~request_id ~binding ~method_ ~args_json
  | None ->
      Async.fail
        (Binding_rpc.Error "Thunder generic binding access requires a request id in context.")
