val get_text : binding:string -> key:string -> Request.t -> string option Async.t
val get_bytes : binding:string -> key:string -> Request.t -> bytes option Async.t
val put_text : binding:string -> key:string -> value:string -> Request.t -> unit Async.t
val put_bytes : binding:string -> key:string -> value:bytes -> Request.t -> unit Async.t
