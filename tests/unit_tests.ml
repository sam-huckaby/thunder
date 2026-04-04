let assert_true msg cond = if not cond then failwith msg

let assert_equal_string msg expected actual =
  if expected <> actual then failwith (msg ^ " expected=" ^ expected ^ " actual=" ^ actual)

let assert_equal_int msg expected actual =
  if expected <> actual then
    failwith
      (msg ^ " expected=" ^ string_of_int expected ^ " actual=" ^ string_of_int actual)

let assert_equal_opt_string msg expected actual =
  if expected <> actual then
    let render = function None -> "None" | Some value -> "Some(" ^ value ^ ")" in
    failwith (msg ^ " expected=" ^ render expected ^ " actual=" ^ render actual)

let () =
  let k1 = Thunder_core.Context.key () in
  let k2 = Thunder_core.Context.key () in
  let ctx0 = Thunder_core.Context.empty in
  let ctx1 = Thunder_core.Context.add ctx0 k1 "v1" in
  let ctx = Thunder_core.Context.add ctx1 k2 42 in
  assert_equal_string "context string" "v1"
    (Option.get (Thunder_core.Context.get ctx k1));
  assert_equal_int "context int" 42 (Option.get (Thunder_core.Context.get ctx k2));
  assert_true "context absent"
    (Thunder_core.Context.get ctx (Thunder_core.Context.key ()) = None)

let () =
  assert_true "method parse" (Method.of_string "get" = Some Method.GET);
  assert_equal_string "method serialize" "POST" (Method.to_string Method.POST)

let () =
  assert_equal_int "status code" 404 (Status.code Status.not_found);
  assert_equal_string "status reason" "Internal Server Error"
    (Status.reason Status.internal_server_error)

let () =
  let headers = Headers.of_list [ ("X-Test", "a"); ("set-cookie", "one"); ("SET-COOKIE", "two") ] in
  assert_equal_string "header case-insensitive" "a" (Option.get (Headers.get headers "x-test"));
  assert_equal_int "set-cookie repeated" 2 (List.length (Headers.get_all headers "set-cookie"))

let () =
  let query = Query.parse "?a=1&a=2&name=hello+world" in
  assert_equal_string "query first" "1" (Option.get (Query.get query "a"));
  assert_equal_int "query repeated" 2 (List.length (Query.get_all query "a"));
  assert_equal_string "query decode" "hello world" (Option.get (Query.get query "name"))

let () =
  let parsed = Cookie.parse_request_header "a=1; b=2" in
  assert_equal_string "cookie parse" "2" (Option.get (Cookie.get parsed "b"));
  let set =
    Cookie.make_set ~path:"/" ~http_only:true ~secure:true ~same_site:Cookie.Lax "sid"
      "abc"
  in
  let wire = Cookie.serialize_set set in
  assert_true "cookie serialization" (String.length wire > 0)

let () =
  let req =
    Request.make ~meth:Method.GET ~url:"https://x.test/users/4?page=3"
      ~headers:(Headers.of_list [ ("Cookie", "theme=dark") ]) ~body:"hello" ()
  in
  assert_equal_string "request path" "/users/4" (Request.path req);
  assert_equal_string "request query" "3" (Option.get (Request.query req "page"));
  assert_equal_string "request cookie" "dark" (Option.get (Request.cookie req "theme"));
  assert_equal_string "request body" "hello" (Request.body_string req)

let () =
  let response =
    Response.text "ok"
    |> fun res -> Response.add_header res "x-a" "1"
    |> fun res -> Response.add_header res "x-a" "2"
    |> fun res -> Response.with_cookie res (Cookie.make_set "a" "b")
  in
  assert_equal_int "response status" 200 (Status.code (Response.status response));
  assert_true "response repeated headers" (List.length (Headers.get_all (Response.headers response) "x-a") = 2);
  assert_true "response set-cookie" (List.length (Headers.get_all (Response.headers response) "set-cookie") = 1)

let () =
  let response = Response.bytes (Bytes.of_string "abc") in
  let encoded = Runtime.encode_response response in
  assert_equal_string "response bytes fallback string" "abc" (Response.body_string response);
  assert_equal_string "encoded bytes body" "" encoded.body;
  assert_equal_opt_string "encoded bytes base64" (Some "YWJj") encoded.body_base64

let () =
  let route_handler = Handler.handler (fun _ -> Response.text "route") in
  let app =
    Router.router
      [ Router.get "/" route_handler; Router.get "/users/:id" route_handler ]
  in
  let req =
    Request.make ~meth:Method.GET ~url:"https://example.com/users/9" ~headers:Headers.empty
      ~body:"" ()
  in
  let out = Handler.run app req in
  assert_equal_string "router dispatch" "route" (Response.body_string out)

let () =
  let async_handler = Handler.handler_async (fun _ -> Async.return (Response.text "async")) in
  let req = Request.make ~meth:Method.GET ~url:"/" ~headers:Headers.empty ~body:"" () in
  let out = Handler.run_async async_handler req |> Async.run in
  assert_equal_string "handler_async" "async" (Response.body_string out)

let () =
  let base = Handler.handler (fun _ -> failwith "boom") in
  let wrapped = Middleware.apply_many [ Middleware.recover; Middleware.logger () ] base in
  let req = Request.make ~meth:Method.GET ~url:"/" ~headers:Headers.empty ~body:"" () in
  let out = Handler.run wrapped req in
  assert_equal_int "recover middleware" 500 (Status.code (Response.status out));
  let async_boom =
    Handler.handler_async (fun _ -> raise (Failure "async boom") |> fun _ -> Async.return (Response.text "never"))
  in
  let async_wrapped = Middleware.recover async_boom in
  let async_out = Handler.run_async async_wrapped req |> Async.run in
  assert_equal_int "recover async middleware" 500 (Status.code (Response.status async_out));
  print_endline "unit_tests: ok"
