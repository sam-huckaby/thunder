exception Error of string

let is_js_backend () =
  match Sys.backend_type with Other "js_of_ocaml" -> true | _ -> false

let fail_native () =
  Async.fail
    (Error
       "Thunder JS binding wrappers are only available in the js_of_ocaml Worker runtime; native executables should not invoke them.")

let get_global_function name =
  try Some (Js_of_ocaml.Js.Unsafe.get Js_of_ocaml.Js.Unsafe.global name) with _ -> None

let get_field_opt obj field =
  try Some (Js_of_ocaml.Js.Unsafe.get obj field) with _ -> None

let bool_of_any_opt value =
  try Some (Js_of_ocaml.Js.to_bool (Js_of_ocaml.Js.Unsafe.coerce value)) with _ -> None

let string_of_any_opt value =
  try Some (Js_of_ocaml.Js.to_string (Js_of_ocaml.Js.Unsafe.coerce value)) with _ -> None

let base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

let base64_char index = String.get base64_chars index

let bytes_to_base64 bytes =
  let len = Bytes.length bytes in
  let out = Buffer.create (((len + 2) / 3) * 4) in
  let rec loop index =
    if index >= len then Buffer.contents out
    else
      let b0 = Char.code (Bytes.get bytes index) in
      let has_b1 = index + 1 < len in
      let has_b2 = index + 2 < len in
      let b1 = if has_b1 then Char.code (Bytes.get bytes (index + 1)) else 0 in
      let b2 = if has_b2 then Char.code (Bytes.get bytes (index + 2)) else 0 in
      let triple = (b0 lsl 16) lor (b1 lsl 8) lor b2 in
      Buffer.add_char out (base64_char ((triple lsr 18) land 0x3f));
      Buffer.add_char out (base64_char ((triple lsr 12) land 0x3f));
      Buffer.add_char out (if has_b1 then base64_char ((triple lsr 6) land 0x3f) else '=');
      Buffer.add_char out (if has_b2 then base64_char (triple land 0x3f) else '=');
      loop (index + 3)
  in
  loop 0

let base64_decode_char = function
  | 'A' .. 'Z' as c -> Char.code c - Char.code 'A'
  | 'a' .. 'z' as c -> Char.code c - Char.code 'a' + 26
  | '0' .. '9' as c -> Char.code c - Char.code '0' + 52
  | '+' -> 62
  | '/' -> 63
  | '=' -> 0
  | c -> invalid_arg ("Invalid base64 character: " ^ String.make 1 c)

let bytes_of_base64 input =
  let len = String.length input in
  if len mod 4 <> 0 then invalid_arg "Invalid base64 length";
  let out = Buffer.create ((len / 4) * 3) in
  let rec loop index =
    if index >= len then Bytes.of_string (Buffer.contents out)
    else
      let c0 = input.[index] in
      let c1 = input.[index + 1] in
      let c2 = input.[index + 2] in
      let c3 = input.[index + 3] in
      let n0 = base64_decode_char c0 in
      let n1 = base64_decode_char c1 in
      let n2 = base64_decode_char c2 in
      let n3 = base64_decode_char c3 in
      let triple = (n0 lsl 18) lor (n1 lsl 12) lor (n2 lsl 6) lor n3 in
      Buffer.add_char out (Char.chr ((triple lsr 16) land 0xff));
      if c2 <> '=' then Buffer.add_char out (Char.chr ((triple lsr 8) land 0xff));
      if c3 <> '=' then Buffer.add_char out (Char.chr (triple land 0xff));
      loop (index + 4)
  in
  loop 0

let require_ok_result value =
  match get_field_opt value "ok" with
  | Some flag ->
      (match bool_of_any_opt flag with
      | Some true -> value
      | _ ->
          let message =
            match get_field_opt value "error" with
            | Some error_obj ->
                (match get_field_opt error_obj "message" with
                | Some raw_message ->
                    Option.value (string_of_any_opt raw_message)
                      ~default:"Unknown binding RPC failure"
                | None -> "Unknown binding RPC failure")
            | None -> "Unknown binding RPC failure"
          in
          raise (Error message))
  | None -> raise (Error "Malformed Thunder binding RPC result: missing 'ok'.")

let promise_to_async promise parse =
  Async.make (fun callback ->
      let settle_ok value =
        try callback (Ok (parse value)) with exn -> callback (Error exn)
      in
      let settle_error value =
        let message =
          Option.value (string_of_any_opt value) ~default:"Binding RPC promise rejected"
        in
        callback (Error (Error message))
      in
      let on_fulfilled = Js_of_ocaml.Js.wrap_callback settle_ok in
      let on_rejected = Js_of_ocaml.Js.wrap_callback settle_error in
      let then_fn = Js_of_ocaml.Js.Unsafe.get promise "then" in
      let catch_fn = Js_of_ocaml.Js.Unsafe.get promise "catch" in
      ignore
        (Js_of_ocaml.Js.Unsafe.fun_call then_fn
           [| Js_of_ocaml.Js.Unsafe.inject on_fulfilled |]);
      ignore
        (Js_of_ocaml.Js.Unsafe.fun_call catch_fn
           [| Js_of_ocaml.Js.Unsafe.inject on_rejected |]))

let call request_id op fields parse =
  if not (is_js_backend ()) then fail_native ()
  else
    match get_global_function "__thunder_binding_rpc" with
    | None -> Async.fail (Error "Thunder binding RPC global is not installed.")
    | Some rpc ->
        let args = Js_of_ocaml.Js.Unsafe.obj (Array.of_list fields) in
        let promise =
          Js_of_ocaml.Js.Unsafe.fun_call rpc
            [|
              Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string request_id);
              Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string op);
              Js_of_ocaml.Js.Unsafe.inject args;
            |]
        in
        promise_to_async promise (fun result -> parse (require_ok_result result))

let invoke_json ~request_id ~binding ~method_ ~args_json =
  call request_id "binding.invoke"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("method", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string method_));
      ("args_json", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string args_json));
    ]
    (fun result ->
      match get_field_opt result "value_json" with
      | Some value -> Option.value (string_of_any_opt value) ~default:"null"
      | None -> "null")

let r2_get_text ~request_id ~binding ~key =
  call request_id "r2.get"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("key", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string key));
    ]
    (fun result -> match get_field_opt result "value" with Some value -> string_of_any_opt value | None -> None)

let r2_get_bytes ~request_id ~binding ~key =
  call request_id "r2.get"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("key", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string key));
      ("type", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string "bytes"));
    ]
    (fun result ->
      match get_field_opt result "value_base64" with
      | Some raw_value -> Option.map bytes_of_base64 (string_of_any_opt raw_value)
      | None -> None)

let r2_put_text ~request_id ~binding ~key ~value =
  call request_id "r2.put"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("key", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string key));
      ("value", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string value));
    ]
    (fun _ -> ())

let r2_put_bytes ~request_id ~binding ~key ~value =
  call request_id "r2.put"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("key", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string key));
      ( "value_base64",
        Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string (bytes_to_base64 value)) );
    ]
    (fun _ -> ())

let d1_query_json ~request_id ~binding ~sql ~action ?params_json () =
  let fields =
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("sql", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string sql));
      ("action", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string action));
    ]
    @
    match params_json with
    | Some value -> [ ("params_json", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string value)) ]
    | None -> []
  in
  call request_id "d1.query" fields (fun result ->
      match get_field_opt result "value_json" with
      | Some value -> Option.value (string_of_any_opt value) ~default:"null"
      | None -> "null")

let service_fetch_json ~request_id ~binding ~url ?init_json () =
  let fields =
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("url", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string url));
    ]
    @
    match init_json with
    | Some value -> [ ("init_json", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string value)) ]
    | None -> []
  in
  call request_id "service.fetch" fields (fun result ->
      match get_field_opt result "value_json" with
      | Some value -> Option.value (string_of_any_opt value) ~default:"null"
      | None -> "null")

let durable_object_call_json ~request_id ~binding ~name ~method_ ~args_json =
  call request_id "durable_object.call"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("name", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string name));
      ("method", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string method_));
      ("args_json", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string args_json));
    ]
    (fun result ->
      match get_field_opt result "value_json" with
      | Some value -> Option.value (string_of_any_opt value) ~default:"null"
      | None -> "null")

let ai_run_json ~request_id ~binding ~model ~input_json ?options_json () =
  let fields =
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("model", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string model));
      ("input_json", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string input_json));
    ]
    @
    match options_json with
    | Some value -> [ ("options_json", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string value)) ]
    | None -> []
  in
  call request_id "ai.run" fields (fun result ->
      match get_field_opt result "value_json" with
      | Some value -> Option.value (string_of_any_opt value) ~default:"null"
      | None -> "null")

let queue_send_text ~request_id ~binding ~value =
  call request_id "queue.send"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("value", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string value));
    ]
    (fun _ -> ())

let queue_send_bytes ~request_id ~binding ~value =
  call request_id "queue.send"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ( "value_base64",
        Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string (bytes_to_base64 value)) );
    ]
    (fun _ -> ())

let queue_send_json ~request_id ~binding ~value_json =
  call request_id "queue.send"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("value_json", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string value_json));
    ]
    (fun _ -> ())

let queue_send_batch_json ~request_id ~binding ~messages_json =
  call request_id "queue.send_batch"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ( "messages_json",
        Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string messages_json) );
    ]
    (fun _ -> ())

let get_text ~request_id ~binding ~key =
  call request_id "kv.get"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("key", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string key));
    ]
    (fun result ->
      match get_field_opt result "value" with
      | Some value -> string_of_any_opt value
      | None -> None)

let get_bytes ~request_id ~binding ~key =
  call request_id "kv.get"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("key", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string key));
      ("type", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string "bytes"));
    ]
    (fun result ->
      match get_field_opt result "value_base64" with
      | Some raw_value -> Option.map bytes_of_base64 (string_of_any_opt raw_value)
      | None -> None)

let put_text ~request_id ~binding ~key ~value =
  call request_id "kv.put"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("key", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string key));
      ("value", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string value));
    ]
    (fun _ -> ())

let put_bytes ~request_id ~binding ~key ~value =
  call request_id "kv.put"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("key", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string key));
      ( "value_base64",
        Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string (bytes_to_base64 value)) );
    ]
    (fun _ -> ())

let delete ~request_id ~binding ~key =
  call request_id "kv.delete"
    [
      ("binding", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string binding));
      ("key", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string key));
    ]
    (fun _ -> ())
