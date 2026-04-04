let app =
  Router.router
    [
      Router.get "/dashboard/:id"
        (Handler.handler_async (fun req ->
             let id = Option.value (Request.param req "id") ~default:"1" in
             Async.bind
               (Thunder.Worker.D1.first_json ~binding:"DB"
                  ~sql:"select * from dashboards where id = ?" ~params_json:("[" ^ id ^ "]") req)
               (fun row_json ->
                 Async.bind
                   (Thunder.Worker.Service.fetch_json ~binding:"API"
                      ~url:"https://svc.test/context" req)
                   (fun service_json ->
                     Async.map
                       (Thunder.Worker.AI.run_json ~binding:"AI" ~model:"@cf/meta/demo"
                          ~input_json:
                            ( {|{"dashboard":|} ^ row_json ^ {|,"service":|}
                            ^ service_json ^ "}" ) req)
                       (fun ai_json ->
                         Response.json
                           ( {|{"row":|} ^ row_json ^ {|,"service":|} ^ service_json
                           ^ {|,"ai":|} ^ ai_json ^ "}" ))))));
      Router.post "/fallback"
        (Handler.handler_async (fun req ->
             Async.map
               (Thunder.Worker.Generic.invoke_json ~binding:"CUSTOM" ~method_:"ping"
                  ~args_json:(Request.body_string req) req)
               Response.json));
    ]

let () =
  let req =
    Request.make ~meth:Method.GET ~url:"https://example.com/dashboard/7"
      ~headers:Headers.empty ~body:"" ()
    |> fun request -> Worker.with_request_id request (Some "example-full-stack")
  in
  let _ = Handler.run_async app req in
  print_endline "cloudflare_full_stack example configured"
