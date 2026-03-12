type t = Handler.t -> Handler.t
type middleware = t

let compose outer inner handler = outer (inner handler)

let apply_many middlewares handler =
  List.fold_right (fun middleware acc -> middleware acc) middlewares handler

let recover next =
  Handler.handler (fun req ->
      try Handler.run next req with _ -> Response.empty ~status:Status.internal_server_error ())

let logger ?(log = fun _ -> ()) () next =
  Handler.handler (fun req ->
      let line = Method.to_string (Request.meth req) ^ " " ^ Request.path req in
      log line;
      Handler.run next req)

let add_response_header name value next =
  Handler.handler (fun req ->
      let response = Handler.run next req in
      Response.add_header response name value)
