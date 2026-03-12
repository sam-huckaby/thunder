let assert_eq msg expected actual =
  if expected <> actual then failwith (msg ^ " expected=" ^ expected ^ " actual=" ^ actual)

let hello_app =
  Thunder.router
    [ Thunder.get "/" (Thunder.handler (fun _ -> Thunder.html "<h1>Hello</h1>")) ]

let json_app =
  Thunder.router
    [
      Thunder.get "/health" (Thunder.handler (fun _ -> Thunder.json "{\"ok\":true}"));
      Thunder.post "/echo"
        (Thunder.handler (fun req -> Thunder.json (Thunder.Request.body_string req)));
    ]

let () =
  let req =
    Thunder.Request.make ~meth:Thunder.Method.GET ~url:"https://example.com/"
      ~headers:Thunder.Headers.empty ~body:"" ()
  in
  let res = Thunder.Handler.run hello_app req in
  assert_eq "hello example" "<h1>Hello</h1>" (Thunder.Response.body_string res)

let () =
  let req =
    Thunder.Request.make ~meth:Thunder.Method.POST ~url:"https://example.com/echo"
      ~headers:Thunder.Headers.empty ~body:"{\"x\":1}" ()
  in
  let res = Thunder.Handler.run json_app req in
  assert_eq "echo example" "{\"x\":1}" (Thunder.Response.body_string res);
  print_endline "example_smoke_tests: ok"
