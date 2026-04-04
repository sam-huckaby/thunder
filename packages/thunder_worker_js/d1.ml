let require_request_id req =
  match Worker.request_id req with
  | Some request_id -> request_id
  | None -> raise (Binding_rpc.Error "Thunder D1 access requires a request id in context.")

let query_json ~binding ~sql ~action ?params_json req =
  Binding_rpc.d1_query_json ~request_id:(require_request_id req) ~binding ~sql ~action
    ?params_json ()

let first_json ~binding ~sql ?params_json req =
  query_json ~binding ~sql ~action:"first" ?params_json req

let all_json ~binding ~sql ?params_json req =
  query_json ~binding ~sql ~action:"all" ?params_json req

let raw_json ~binding ~sql ?params_json req =
  query_json ~binding ~sql ~action:"raw" ?params_json req

let run_json ~binding ~sql ?params_json req =
  query_json ~binding ~sql ~action:"run" ?params_json req
