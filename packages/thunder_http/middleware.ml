type t = Handler.t -> Handler.t
type middleware = t

let compose outer inner handler = outer (inner handler)

let apply_many middlewares handler =
  List.fold_right (fun middleware acc -> middleware acc) middlewares handler

let recover next =
  Handler.handler_async (fun req ->
      try
        Async.catch (Handler.run_async next req) (fun _ ->
            Async.return (Response.empty ~status:Status.internal_server_error ()))
      with _ -> Async.return (Response.empty ~status:Status.internal_server_error ()))

let logger ?(log = fun _ -> ()) () next =
  Handler.handler_async (fun req ->
      let line = Method.to_string (Request.meth req) ^ " " ^ Request.path req in
      log line;
      Handler.run_async next req)

let add_response_header name value next =
  Handler.handler_async (fun req ->
      Async.map (Handler.run_async next req) (fun response ->
          Response.add_header response name value))
