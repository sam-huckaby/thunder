let app =
  Thunder.router
    [
      Thunder.get "/users/:id"
        (Thunder.handler (fun req ->
             let id = Option.value (Thunder.Request.param req "id") ~default:"unknown" in
             let page = Option.value (Thunder.Request.query req "page") ~default:"1" in
             Thunder.text ("id=" ^ id ^ ", page=" ^ page)));
    ]

let () =
  let req =
    Thunder.Request.make ~meth:Thunder.Method.GET
      ~url:"https://example.com/users/42?page=2" ~headers:Thunder.Headers.empty
      ~body:"" ()
  in
  let res = Thunder.Handler.run app req in
  print_endline (Thunder.Response.body_string res)
