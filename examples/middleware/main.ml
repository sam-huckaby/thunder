let base_app =
  Thunder.router
    [
      Thunder.get "/ok" (Thunder.handler (fun _ -> Thunder.text "ok"));
      Thunder.get "/boom"
        (Thunder.handler (fun _ -> failwith "demo exception for recover middleware"));
    ]

let app =
  Thunder.Middleware.apply_many
    [ Thunder.logger (); Thunder.recover; Thunder.Middleware.add_response_header "x-thunder" "1" ]
    base_app

let () =
  let req =
    Thunder.Request.make ~meth:Thunder.Method.GET ~url:"https://example.com/boom"
      ~headers:Thunder.Headers.empty ~body:"" ()
  in
  let res = Thunder.Handler.run app req in
  Printf.printf "status=%d\n" (Thunder.Status.code (Thunder.Response.status res))
