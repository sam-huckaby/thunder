let app =
  Router.router
    [
      Router.get "/" (Handler.handler (fun _ -> Response.text "hello from thunder wasm"));
      Router.get "/health" (Handler.handler (fun _ -> Response.json "{\"ok\":true}"));
      Router.post "/echo"
        (Handler.handler (fun req -> Response.json (Request.body_string req)));
    ]

let json_parse (value : string) : Js_of_ocaml.Js.Unsafe.any =
  let parse = Js_of_ocaml.Js.Unsafe.get Js_of_ocaml.Js.Unsafe.global "JSON" in
  let parse_fn = Js_of_ocaml.Js.Unsafe.get parse "parse" in
  Js_of_ocaml.Js.Unsafe.fun_call parse_fn
    [| Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string value) |]

let json_stringify (value : Js_of_ocaml.Js.Unsafe.any) : string =
  let json = Js_of_ocaml.Js.Unsafe.get Js_of_ocaml.Js.Unsafe.global "JSON" in
  let stringify = Js_of_ocaml.Js.Unsafe.get json "stringify" in
  let js_string =
    Js_of_ocaml.Js.Unsafe.fun_call stringify [| Js_of_ocaml.Js.Unsafe.inject value |]
  in
  Js_of_ocaml.Js.to_string js_string

let get_string_field (obj : Js_of_ocaml.Js.Unsafe.any) field default =
  try
    let value = Js_of_ocaml.Js.Unsafe.get obj field in
    Js_of_ocaml.Js.to_string value
  with _ -> default

let request_of_payload payload_json =
  let payload = json_parse payload_json in
  let meth = get_string_field payload "method" "GET" in
  let url = get_string_field payload "url" "https://example.com/" in
  let body = get_string_field payload "body" "" in
  let meth = Option.value (Method.of_string meth) ~default:Method.GET in
  Request.make ~meth ~url ~headers:Headers.empty ~body ()

let response_to_json response =
  let status = Status.code (Response.status response) in
  let headers = Headers.to_list (Response.headers response) in
  let body = Response.body_string response in
  let header_entries =
    headers
    |> List.map (fun (name, value) ->
           let pair = Js_of_ocaml.Js.array [| Js_of_ocaml.Js.string name; Js_of_ocaml.Js.string value |] in
           Js_of_ocaml.Js.Unsafe.inject pair)
    |> Array.of_list
  in
  let headers_array = Js_of_ocaml.Js.array header_entries in
  let obj =
    Js_of_ocaml.Js.Unsafe.obj
      [|
        ("status", Js_of_ocaml.Js.Unsafe.inject status);
        ("headers", Js_of_ocaml.Js.Unsafe.inject headers_array);
        ("body", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string body));
      |]
  in
  json_stringify obj

let thunder_handle_json payload_json =
  try
    let request = request_of_payload payload_json in
    let response = Handler.run app request in
    response_to_json response
  with exn ->
    let message = Printexc.to_string exn in
    response_to_json (Response.text ~status:Status.internal_server_error message)

let () =
  Js_of_ocaml.Js.Unsafe.set Js_of_ocaml.Js.Unsafe.global "thunder_handle_json"
    (Js_of_ocaml.Js.wrap_callback (fun payload_js ->
         let payload = Js_of_ocaml.Js.to_string payload_js in
         Js_of_ocaml.Js.string (thunder_handle_json payload)))
