let app =
  Thunder.router
    [
      Thunder.get "/health"
        (Thunder.handler (fun _ -> Thunder.json "{\"ok\":true}"));
      Thunder.post "/echo"
        (Thunder.handler (fun req -> Thunder.json (Thunder.Request.body_string req)));
    ]

let () =
  let req =
    Thunder.Request.make ~meth:Thunder.Method.GET ~url:"https://example.com/health"
      ~headers:Thunder.Headers.empty ~body:"" ()
  in
  let res = Thunder.Handler.run app req in
  print_endline (Thunder.Response.body_string res)
