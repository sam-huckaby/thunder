let app =
  Thunder.router
    [
      Thunder.get "/"
        (Thunder.handler (fun req ->
             let env = Thunder.Worker.env req in
             let message =
               match Thunder.Worker.env_binding env "GREETING" with
               | Some v -> v
               | None -> "missing"
             in
             Thunder.text message));
    ]

let () =
  let req =
    Thunder.Request.make ~meth:Thunder.Method.GET ~url:"https://example.com/" ~headers:Thunder.Headers.empty
      ~body:"" ()
    |> fun r -> Thunder.Worker.with_env r (Thunder.Worker.create_env [ ("GREETING", "hello from env") ])
  in
  let res = Thunder.Handler.run app req in
  print_endline (Thunder.Response.body_string res)
