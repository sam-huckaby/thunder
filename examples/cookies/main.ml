let app =
  Thunder.router
    [
      Thunder.get "/cookies"
        (Thunder.handler (fun req ->
             let incoming =
               match Thunder.Request.cookie req "session" with
               | Some value -> value
               | None -> "none"
             in
             Thunder.text ("session=" ^ incoming)
             |> fun response ->
             Thunder.Response.with_cookie response
               (Thunder.Cookie.make_set ~path:"/" ~http_only:true "session" "new-token")));
    ]

let () =
  let headers = Thunder.Headers.of_list [ ("cookie", "session=abc123") ] in
  let req =
    Thunder.Request.make ~meth:Thunder.Method.GET ~url:"https://example.com/cookies"
      ~headers ~body:"" ()
  in
  let res = Thunder.Handler.run app req in
  print_endline (Thunder.Response.body_string res)
