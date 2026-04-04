let app =
  Router.router
    [
      Router.get "/kv/:key"
        (Handler.handler_async (fun req ->
             let key = Option.value (Request.param req "key") ~default:"sample" in
             Async.map (Thunder.Worker.KV.get_text ~binding:"MY_KV" ~key req) (function
                 | Some value -> Response.text value
                 | None -> Response.text ~status:Status.not_found "missing")));
      Router.get "/r2/:key"
        (Handler.handler_async (fun req ->
             let key = Option.value (Request.param req "key") ~default:"blob.txt" in
             Async.map (Thunder.Worker.R2.get_text ~binding:"FILES" ~key req) (function
                 | Some value -> Response.text value
                 | None -> Response.text ~status:Status.not_found "missing")));
    ]

let () =
  let req =
    Request.make ~meth:Method.GET ~url:"https://example.com/kv/demo" ~headers:Headers.empty
      ~body:"" ()
    |> fun request -> Worker.with_request_id request (Some "example-storage")
  in
  let _ = Handler.run_async app req in
  print_endline "cloudflare_storage example configured"
