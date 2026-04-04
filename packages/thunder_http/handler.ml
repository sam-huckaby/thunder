type t = Handler of (Request.t -> Response.t Async.t)
type handler = t

let handler fn = Handler (fun req -> Async.return (fn req))
let handler_async fn = Handler fn
let run_async (Handler fn) req = fn req
let run handler req = run_async handler req |> Async.run
