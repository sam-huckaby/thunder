let app =
  Router.router
    [
      Router.post "/jobs"
        (Handler.handler_async (fun req ->
             Async.map
               (Thunder.Worker.Queues.send_json ~binding:"JOBS"
                  ~value_json:(Request.body_string req) req)
               (fun () -> Response.text "queued")));
      Router.get "/do/:name"
        (Handler.handler_async (fun req ->
             let name = Option.value (Request.param req "name") ~default:"default" in
             Async.map
               (Thunder.Worker.Durable_object.call_json ~binding:"MY_DO" ~name
                  ~method_:"greet" ~args_json:{|["thunder"]|} req)
               Response.json));
    ]

let () =
  let req =
    Request.make ~meth:Method.POST ~url:"https://example.com/jobs" ~headers:Headers.empty
      ~body:{|{"id":1}|} ()
    |> fun request -> Worker.with_request_id request (Some "example-coordination")
  in
  let _ = Handler.run_async app req in
  print_endline "cloudflare_coordination example configured"
