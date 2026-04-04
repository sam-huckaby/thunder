let lookup_or_missing ~binding ~key req =
  Async.map (Thunder.Worker.KV.get_text ~binding ~key req) (function
      | Some value -> value
      | None -> "missing")

let app =
  Router.router
    [
      Router.get "/inspect/:key"
        (Handler.handler_async (fun req ->
             let key = Option.value (Request.param req "key") ~default:"demo" in
             Async.bind (lookup_or_missing ~binding:"ze_env" ~key req) (fun env_value ->
                 Async.bind (lookup_or_missing ~binding:"ze_files" ~key req) (fun file_value ->
                     Async.map (lookup_or_missing ~binding:"ze_snapshots" ~key req)
                       (fun snapshot_value ->
                         Response.json
                           (Printf.sprintf
                              {|{"key":"%s","ze_env":%S,"ze_files":%S,"ze_snapshots":%S}|}
                              key env_value file_value snapshot_value))))));
    ]

let () =
  let req =
    Request.make ~meth:Method.GET ~url:"https://example.com/inspect/demo"
      ~headers:Headers.empty ~body:"" ()
    |> fun request -> Worker.with_request_id request (Some "example-zephyr")
  in
  let _ = Handler.run_async app req in
  print_endline "zephyr_kv_inspector example configured"
