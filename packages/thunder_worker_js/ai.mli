val run_json :
  binding:string ->
  model:string ->
  input_json:string ->
  ?options_json:string ->
  Request.t ->
  string Async.t

val run_text :
  binding:string ->
  model:string ->
  input_json:string ->
  ?options_json:string ->
  Request.t ->
  string Async.t
