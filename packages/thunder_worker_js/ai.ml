let require_request_id req =
  match Worker.request_id req with
  | Some request_id -> request_id
  | None -> raise (Binding_rpc.Error "Thunder AI access requires a request id in context.")

let run_json ~binding ~model ~input_json ?options_json req =
  Binding_rpc.ai_run_json ~request_id:(require_request_id req) ~binding ~model ~input_json
    ?options_json ()

let run_text ~binding ~model ~input_json ?options_json req =
  Async.map (run_json ~binding ~model ~input_json ?options_json req) (fun value_json ->
      let trimmed = String.trim value_json in
      if String.length trimmed >= 2 && trimmed.[0] = '"' && trimmed.[String.length trimmed - 1] = '"'
      then String.sub trimmed 1 (String.length trimmed - 2)
      else value_json)
