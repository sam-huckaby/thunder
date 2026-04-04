let app =
  Router.router
    [
      Router.get "/support/:slug"
        (Handler.handler_async (fun req ->
             let slug = Option.value (Request.param req "slug") ~default:"welcome" in
             Async.bind
               (Thunder.Worker.KV.get_text ~binding:"MY_KV" ~key:slug req)
               (fun article ->
                 Async.bind
                    (Thunder.Worker.Service.fetch_json ~binding:"API"
                       ~url:("https://internal.service/context/" ^ slug) req)
                    (fun context_json ->
                      let article_json =
                        match article with
                        | Some value -> Printf.sprintf "%S" value
                        | None -> "null"
                      in
                      let input_json =
                        {|{"article":|} ^ article_json ^ {|,"context":|} ^ context_json ^ "}"
                      in
                      let response_json =
                        {|{"slug":|} ^ Printf.sprintf "%S" slug ^ {|,"article":|}
                        ^ article_json ^ {|,"context":|} ^ context_json ^ {|,"ai":|}
                      in
                      Async.map
                        (Thunder.Worker.AI.run_json ~binding:"AI" ~model:"@cf/meta/demo"
                           ~input_json req)
                        (fun ai_json ->
                          Response.json (response_json ^ ai_json ^ "}"))))));
      Router.post "/support/fallback"
        (Handler.handler_async (fun req ->
             Async.map
               (Thunder.Worker.Generic.invoke_json ~binding:"CUSTOM" ~method_:"ping"
                  ~args_json:(Request.body_string req) req)
               Response.json));
    ]

let () =
  let req =
    Request.make ~meth:Method.GET ~url:"https://example.com/support/welcome"
      ~headers:Headers.empty ~body:"" ()
    |> fun request -> Worker.with_request_id request (Some "example-support")
  in
  let _ = Handler.run_async app req in
  print_endline "cloudflare_support_assistant example configured"
