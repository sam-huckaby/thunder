let app =
  Router.router
    [
      Router.get "/"
        (Handler.handler (fun _ ->
             Response.html
               "<html><head><meta charset=\"utf-8\" /><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" /><title>Thunder</title><style>html,body{height:100%;margin:0}body{display:grid;place-items:center;background:#fff;color:#111;font-family:ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif}h1{margin:0;font-size:clamp(1.75rem,4vw,3rem);font-weight:600;letter-spacing:0.01em}</style></head><body><h1>Welcome to the storm</h1></body></html>"));
      Router.get "/health" (Handler.handler (fun _ -> Response.json "{\"ok\":true}"));
    ]

let app = Middleware.recover app

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

let get_field_opt (obj : Js_of_ocaml.Js.Unsafe.any) field =
  try
    let value = Js_of_ocaml.Js.Unsafe.get obj field in
    Some value
  with _ -> None

let get_string_opt (value : Js_of_ocaml.Js.Unsafe.any) =
  try Some (Js_of_ocaml.Js.to_string (Js_of_ocaml.Js.Unsafe.coerce value)) with _ -> None

let get_string_field_opt obj field =
  match get_field_opt obj field with
  | None -> None
  | Some value -> get_string_opt value

let get_string_field obj field default =
  Option.value (get_string_field_opt obj field) ~default

let get_array_length (value : Js_of_ocaml.Js.Unsafe.any) =
  try
    let length = Js_of_ocaml.Js.Unsafe.get value "length" in
    int_of_float (Js_of_ocaml.Js.float_of_number length)
  with _ -> 0

let get_int_field_opt obj field =
  match get_field_opt obj field with
  | None -> None
  | Some value ->
      try
        Some
          (int_of_float
             (Js_of_ocaml.Js.float_of_number (Js_of_ocaml.Js.Unsafe.coerce value)))
      with _ -> None

let array_to_list parse (value : Js_of_ocaml.Js.Unsafe.any) =
  let rec loop index acc =
    if index >= get_array_length value then List.rev acc
    else
      let next =
        try parse (Js_of_ocaml.Js.Unsafe.get value index) :: acc with _ -> acc
      in
      loop (index + 1) next
  in
  loop 0 []

let string_pairs_field obj field =
  match get_field_opt obj field with
  | None -> []
  | Some value ->
      array_to_list
        (fun pair ->
          let left =
            Js_of_ocaml.Js.Unsafe.get pair 0
            |> Js_of_ocaml.Js.Unsafe.coerce |> Js_of_ocaml.Js.to_string
          in
          let right =
            Js_of_ocaml.Js.Unsafe.get pair 1
            |> Js_of_ocaml.Js.Unsafe.coerce |> Js_of_ocaml.Js.to_string
          in
          (left, right))
        value

let string_list_field obj field =
  match get_field_opt obj field with
  | None -> []
  | Some value ->
      array_to_list
        (fun item -> Js_of_ocaml.Js.to_string (Js_of_ocaml.Js.Unsafe.coerce item))
        value

let decode_base64 value =
  let atob = Js_of_ocaml.Js.Unsafe.get Js_of_ocaml.Js.Unsafe.global "atob" in
  let decoded =
    Js_of_ocaml.Js.Unsafe.fun_call atob
      [| Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string value) |]
  in
  Js_of_ocaml.Js.to_string (Js_of_ocaml.Js.Unsafe.coerce decoded)

let decoded_request_of_payload payload_json =
  let payload = json_parse payload_json in
  let version = Option.value (get_int_field_opt payload "v") ~default:1 in
  if version <> 1 then failwith ("Unsupported Thunder ABI version: " ^ string_of_int version);
  let body =
    match get_string_field_opt payload "body" with
    | Some value -> value
    | None ->
        Option.value
          (Option.map decode_base64 (get_string_field_opt payload "body_base64"))
          ~default:""
  in
  Runtime.
    {
      meth = get_string_field payload "method" "GET";
      url = get_string_field payload "url" "https://example.com/";
      headers = string_pairs_field payload "headers";
      body;
      env = Worker.create_env (string_pairs_field payload "env_bindings");
      ctx = Worker.create_ctx (string_list_field payload "ctx_features");
    }

let response_to_json (response : Runtime.encoded_response) =
  let header_entries =
    response.headers
    |> List.map (fun (name, value) ->
           let pair = Js_of_ocaml.Js.array [| Js_of_ocaml.Js.string name; Js_of_ocaml.Js.string value |] in
           Js_of_ocaml.Js.Unsafe.inject pair)
    |> Array.of_list
  in
  let headers_array = Js_of_ocaml.Js.array header_entries in
  let obj =
    Js_of_ocaml.Js.Unsafe.obj
      [|
        ("status", Js_of_ocaml.Js.Unsafe.inject response.status);
        ("headers", Js_of_ocaml.Js.Unsafe.inject headers_array);
        ("body", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string response.body));
      |]
  in
  json_stringify obj

let thunder_handle_json payload_json =
  try
    let request = decoded_request_of_payload payload_json in
    let response = Runtime.serve app request in
    response_to_json response
  with exn ->
    let message = Printexc.to_string exn in
    response_to_json
      (Runtime.encode_response (Response.text ~status:Status.internal_server_error message))

let () =
  Js_of_ocaml.Js.Unsafe.set Js_of_ocaml.Js.Unsafe.global "thunder_handle_json"
    (Js_of_ocaml.Js.wrap_callback (fun payload_js ->
         let payload = Js_of_ocaml.Js.to_string payload_js in
         Js_of_ocaml.Js.string (thunder_handle_json payload)))
