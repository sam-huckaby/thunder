let app =
  Router.router
    [
      Router.get "/customers/:id"
        (Handler.handler_async (fun req ->
             let id = Option.value (Request.param req "id") ~default:"1" in
             Async.map
               (Thunder.Worker.D1.first_json ~binding:"DB"
                  ~sql:"select * from customers where id = ?" ~params_json:("[" ^ id ^ "]") req)
               Response.json));
      Router.get "/customers"
        (Handler.handler_async (fun req ->
             let company = Option.value (Request.query req "company") ~default:"Thunder" in
             Async.map
               (Thunder.Worker.D1.all_json ~binding:"DB"
                  ~sql:"select * from customers where company = ?"
                  ~params_json:(Printf.sprintf {|[%S]|} company) req)
               Response.json));
    ]

let () =
  let req =
    Request.make ~meth:Method.GET ~url:"https://example.com/customers/7"
      ~headers:Headers.empty ~body:"" ()
    |> fun request -> Worker.with_request_id request (Some "example-d1")
  in
  let _ = Handler.run_async app req in
  print_endline "cloudflare_d1 example configured"
