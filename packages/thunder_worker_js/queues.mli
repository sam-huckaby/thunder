val send_text : binding:string -> value:string -> Request.t -> unit Async.t
val send_bytes : binding:string -> value:bytes -> Request.t -> unit Async.t
val send_json : binding:string -> value_json:string -> Request.t -> unit Async.t
val send_batch_json : binding:string -> messages_json:string -> Request.t -> unit Async.t
