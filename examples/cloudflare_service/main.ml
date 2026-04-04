let search_init_json body =
  Printf.sprintf
    {|{"method":"POST","headers":{"content-type":"application/json"},"body":%S}|}
    body

let app =
  Router.router
    [
      Router.get "/proxy/health"
        (Handler.handler_async (fun req ->
             Async.map
               (Thunder.Worker.Service.fetch_json ~binding:"API"
                  ~url:"https://internal.service/health" req)
               Response.json));
      Router.post "/proxy/search"
        (Handler.handler_async (fun req ->
             Async.map
               (Thunder.Worker.Service.fetch_json ~binding:"API"
                  ~url:"https://internal.service/search"
                  ~init_json:(search_init_json (Request.body_string req)) req)
               Response.json));
    ]

let () =
  let req =
    Request.make ~meth:Method.GET ~url:"https://example.com/proxy/health"
      ~headers:Headers.empty ~body:"" ()
    |> fun request -> Worker.with_request_id request (Some "example-service")
  in
  let _ = Handler.run_async app req in
  print_endline "cloudflare_service example configured"
