let require_request_id req =
  match Worker.request_id req with
  | Some request_id -> request_id
  | None -> raise (Binding_rpc.Error "Thunder service binding access requires a request id in context.")

let fetch_json ~binding ~url ?init_json req =
  Binding_rpc.service_fetch_json ~request_id:(require_request_id req) ~binding ~url
    ?init_json ()
