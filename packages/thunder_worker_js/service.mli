val fetch_json :
  binding:string -> url:string -> ?init_json:string -> Request.t -> string Async.t
