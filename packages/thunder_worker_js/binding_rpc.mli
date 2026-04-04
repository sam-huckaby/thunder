exception Error of string

val invoke_json :
  request_id:string -> binding:string -> method_:string -> args_json:string -> string Async.t
val r2_get_text : request_id:string -> binding:string -> key:string -> string option Async.t
val r2_get_bytes : request_id:string -> binding:string -> key:string -> bytes option Async.t
val r2_put_text : request_id:string -> binding:string -> key:string -> value:string -> unit Async.t
val r2_put_bytes : request_id:string -> binding:string -> key:string -> value:bytes -> unit Async.t
val d1_query_json :
  request_id:string ->
  binding:string ->
  sql:string ->
  action:string ->
  ?params_json:string ->
  unit ->
  string Async.t
val service_fetch_json :
  request_id:string -> binding:string -> url:string -> ?init_json:string -> unit -> string Async.t
val durable_object_call_json :
  request_id:string ->
  binding:string ->
  name:string ->
  method_:string ->
  args_json:string ->
  string Async.t
val ai_run_json :
  request_id:string -> binding:string -> model:string -> input_json:string -> ?options_json:string -> unit -> string Async.t
val queue_send_text : request_id:string -> binding:string -> value:string -> unit Async.t
val queue_send_bytes : request_id:string -> binding:string -> value:bytes -> unit Async.t
val queue_send_json : request_id:string -> binding:string -> value_json:string -> unit Async.t
val queue_send_batch_json : request_id:string -> binding:string -> messages_json:string -> unit Async.t
val get_text : request_id:string -> binding:string -> key:string -> string option Async.t
val get_bytes : request_id:string -> binding:string -> key:string -> bytes option Async.t
val put_text : request_id:string -> binding:string -> key:string -> value:string -> unit Async.t
val put_bytes : request_id:string -> binding:string -> key:string -> value:bytes -> unit Async.t
val delete : request_id:string -> binding:string -> key:string -> unit Async.t
