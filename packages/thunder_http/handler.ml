type t = Handler of (Request.t -> Response.t)
type handler = t

let handler fn = Handler fn
let run (Handler fn) req = fn req
