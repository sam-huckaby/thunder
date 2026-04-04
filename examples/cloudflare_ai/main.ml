let app =
  Router.router
    [
      Router.post "/ai"
        (Handler.handler_async (fun req ->
             Async.map
               (Thunder.Worker.AI.run_json ~binding:"AI" ~model:"@cf/meta/demo"
                  ~input_json:(Request.body_string req) req)
               (fun value_json -> Response.json value_json)));
    ]

let () =
  let req =
    Request.make ~meth:Method.POST ~url:"https://example.com/ai" ~headers:Headers.empty
      ~body:{|{"prompt":"Hello from Thunder"}|} ()
    |> fun request -> Worker.with_request_id request (Some "example-ai")
  in
  let _ = Handler.run_async app req in
  print_endline "cloudflare_ai example configured"
