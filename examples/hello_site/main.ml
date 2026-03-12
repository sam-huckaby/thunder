let app =
  Thunder.router
    [
      Thunder.get "/"
        (Thunder.handler (fun _ ->
             Thunder.html
               "<html><body><h1>Thunder hello_site</h1><p>Edge-native OCaml.</p></body></html>"));
    ]

let () =
  let request =
    Thunder.Request.make ~meth:Thunder.Method.GET ~url:"https://example.com/" ~headers:Thunder.Headers.empty
      ~body:"" ()
  in
  let response = Thunder.Handler.run app request in
  print_endline (Thunder.Response.body_string response)
