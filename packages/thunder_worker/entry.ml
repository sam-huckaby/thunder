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
  try Some (Js_of_ocaml.Js.Unsafe.get obj field) with _ -> None

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
  if version <> 1 && version <> 2 then
    failwith ("Unsupported Thunder ABI version: " ^ string_of_int version);
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
      request_id = get_string_field_opt payload "request_id";
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
           let pair =
             Js_of_ocaml.Js.array [| Js_of_ocaml.Js.string name; Js_of_ocaml.Js.string value |]
           in
           Js_of_ocaml.Js.Unsafe.inject pair)
    |> Array.of_list
  in
  let headers_array = Js_of_ocaml.Js.array header_entries in
  let obj =
    let fields =
      [
        ("status", Js_of_ocaml.Js.Unsafe.inject response.status);
        ("headers", Js_of_ocaml.Js.Unsafe.inject headers_array);
      ]
      @
      match response.body_base64 with
      | Some value -> [ ("body_base64", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string value)) ]
      | None -> [ ("body", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string response.body)) ]
    in
    Js_of_ocaml.Js.Unsafe.obj (Array.of_list fields)
  in
  json_stringify obj

let error_response_json exn =
  let message = Printexc.to_string exn in
  response_to_json
    (Runtime.encode_response (Response.text ~status:Status.internal_server_error message))

let handle_json_async app payload_json =
  try
    let request = decoded_request_of_payload payload_json in
    Async.catch
      (Async.map (Runtime.serve_async app request) response_to_json)
      (fun exn -> Async.return (error_response_json exn))
  with exn -> Async.return (error_response_json exn)

let handle_json app payload_json = handle_json_async app payload_json |> Async.run

let js_promise_of_async_string value =
  let promise_ctor = Js_of_ocaml.Js.Unsafe.get Js_of_ocaml.Js.Unsafe.global "Promise" in
  let executor =
    Js_of_ocaml.Js.wrap_callback (fun resolve reject ->
        Async.respond value (function
          | Ok result ->
              ignore
                (Js_of_ocaml.Js.Unsafe.fun_call resolve
                   [| Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string result) |])
          | Error exn ->
              ignore
                (Js_of_ocaml.Js.Unsafe.fun_call reject
                   [|
                     Js_of_ocaml.Js.Unsafe.inject
                       (Js_of_ocaml.Js.string (Printexc.to_string exn));
                   |])) )
  in
  Js_of_ocaml.Js.Unsafe.new_obj promise_ctor [| Js_of_ocaml.Js.Unsafe.inject executor |]

let export app =
  Js_of_ocaml.Js.Unsafe.set Js_of_ocaml.Js.Unsafe.global "thunder_handle_json"
     (Js_of_ocaml.Js.wrap_callback (fun payload_js ->
          let payload = Js_of_ocaml.Js.to_string payload_js in
          js_promise_of_async_string (handle_json_async app payload)))
