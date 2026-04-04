val first_json :
  binding:string -> sql:string -> ?params_json:string -> Request.t -> string Async.t

val all_json :
  binding:string -> sql:string -> ?params_json:string -> Request.t -> string Async.t

val raw_json :
  binding:string -> sql:string -> ?params_json:string -> Request.t -> string Async.t

val run_json :
  binding:string -> sql:string -> ?params_json:string -> Request.t -> string Async.t
