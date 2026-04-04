let upload_init_json body =
  Printf.sprintf
    {|{"method":"POST","headers":{"content-type":"application/json"},"body":%S}|}
    body

let store_and_enqueue ~key ~body req =
  let size = String.length body in
  let queue_payload = Printf.sprintf {|{"key":%S,"size":%d}|} key size in
  let params_json = Printf.sprintf {|[%S,%d]|} key size in
  Async.bind (Thunder.Worker.R2.put_text ~binding:"FILES" ~key ~value:body req) (fun () ->
      Async.bind
        (Thunder.Worker.Queues.send_json ~binding:"JOBS" ~value_json:queue_payload req)
        (fun () ->
          Async.map
            (Thunder.Worker.D1.run_json ~binding:"DB"
               ~sql:"insert into uploads (key, byte_length) values (?, ?)" ~params_json req)
            (fun db_json ->
              Response.json
                (Printf.sprintf {|{"stored_key":%S,"queued":true,"db":%s}|} key db_json))))

let app =
  Router.router
    [
      Router.post "/ingest/:key"
        (Handler.handler_async (fun req ->
             let key = Option.value (Request.param req "key") ~default:"upload.json" in
             store_and_enqueue ~key ~body:(Request.body_string req) req));
      Router.post "/ingest/notify"
        (Handler.handler_async (fun req ->
             Async.map
               (Thunder.Worker.Service.fetch_json ~binding:"API"
                  ~url:"https://internal.service/uploads/notify"
                  ~init_json:(upload_init_json (Request.body_string req)) req)
               Response.json));
    ]

let () =
  let req =
    Request.make ~meth:Method.POST ~url:"https://example.com/ingest/demo"
      ~headers:Headers.empty ~body:{|{"hello":"world"}|} ()
    |> fun request -> Worker.with_request_id request (Some "example-ingest")
  in
  let _ = Handler.run_async app req in
  print_endline "cloudflare_ingest_pipeline example configured"
