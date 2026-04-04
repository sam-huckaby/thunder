let assert_true msg cond = if not cond then failwith msg

let assert_eq msg expected actual =
  if expected <> actual then failwith (msg ^ " expected=" ^ expected ^ " actual=" ^ actual)

let app =
  Router.router
    [
      Router.get "/" (Handler.handler (fun _ -> Response.text "hello"));
      Router.post "/echo"
        (Handler.handler (fun req -> Response.json (Request.body_string req)));
      Router.get "/json" (Handler.handler (fun _ -> Response.json "{\"ok\":true}"));
      Router.get "/headers"
        (Handler.handler (fun req ->
             let count = List.length (Headers.get_all (Request.headers req) "x-test") in
             Response.text (string_of_int count)));
      Router.get "/redirect"
        (Handler.handler (fun _ -> Response.redirect "https://example.com/next"));
      Router.get "/cookies"
        (Handler.handler (fun _ ->
             Response.text "cookies"
             |> fun response -> Response.with_cookie response (Cookie.make_set "a" "1")
             |> fun response -> Response.with_cookie response (Cookie.make_set "b" "2")));
      Router.get "/env"
        (Handler.handler (fun req ->
             let env = Worker.env req in
             let value = Option.value (Worker.env_binding env "GREETING") ~default:"none" in
             Response.text value));
      Router.get "/ctx"
        (Handler.handler (fun req ->
             let has_wait_until = Worker.ctx_has_feature (Worker.ctx req) "waitUntil" in
             Response.text (if has_wait_until then "waitUntil" else "missing")));
      Router.get "/boom" (Handler.handler (fun _ -> failwith "boom"));
    ]

let run decoded = Runtime.serve (Middleware.recover app) decoded

let base_request path =
  Runtime.
    {
      request_id = None;
      meth = "GET";
      url = "https://example.com" ^ path;
      headers = [];
      body = "";
      env = Worker.create_env [ ("GREETING", "hi") ];
      ctx = Worker.create_ctx [ "waitUntil" ];
    }

let with_method (request : Runtime.decoded_request) meth =
  { request with Runtime.meth = meth }

let with_body (request : Runtime.decoded_request) body =
  { request with Runtime.body = body }

let with_headers (request : Runtime.decoded_request) headers =
  { request with Runtime.headers = headers }

let () =
  let r = run (base_request "/") in
  assert_true "GET works" (r.status = 200);
  assert_eq "GET body" "hello" r.body

let () =
  let r = Runtime.serve_async (Middleware.recover app) (base_request "/") |> Async.run in
  assert_true "GET async serve works" (r.status = 200);
  assert_eq "GET async serve body" "hello" r.body

let () =
  let r = run (base_request "/json") in
  assert_true "json status" (r.status = 200);
  assert_true "json content-type"
    (List.exists (fun (k, v) -> k = "content-type" && v = "application/json") r.headers)

let () =
  let r =
    run
      (base_request "/echo"
      |> fun request -> with_method request "POST"
      |> fun request -> with_body request "{\"x\":1}")
  in
  assert_true "post status" (r.status = 200);
  assert_eq "post body" "{\"x\":1}" r.body

let () =
  let r = run (base_request "/redirect") in
  assert_true "redirect status" (r.status = 302);
  assert_true "redirect location"
    (List.exists (fun (k, v) -> k = "location" && v = "https://example.com/next") r.headers)

let () =
  let r = run (base_request "/cookies") in
  let count = List.length (List.filter (fun (k, _) -> k = "set-cookie") r.headers) in
  assert_true "multiple cookies" (count = 2)

let () =
  let r = run (base_request "/env") in
  assert_eq "env binding" "hi" r.body

let () =
  let r = run (base_request "/ctx") in
  assert_eq "ctx feature" "waitUntil" r.body

let () =
  let r =
    run
      (base_request "/headers"
      |> fun request -> with_headers request [ ("x-test", "a"); ("X-Test", "b") ])
  in
  assert_eq "request repeated headers" "2" r.body

let () =
  let r = run (base_request "/missing") in
  assert_true "not found" (r.status = 404)

let () =
  let r = run (base_request "/" |> fun request -> with_method request "BOGUS") in
  assert_true "invalid method rejected" (r.status = 400)

let () =
  let r = run (base_request "/boom") in
  assert_true "recover behavior" (r.status = 500);
  print_endline "integration_tests: ok"
