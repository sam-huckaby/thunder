type decoded_request = {
  request_id : string option;
  meth : string;
  url : string;
  headers : (string * string) list;
  body : string;
  env : Worker.env;
  ctx : Worker.ctx;
}

type encoded_response = {
  status : int;
  headers : (string * string) list;
  body : string;
  body_base64 : string option;
}

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

let decode_request decoded =
  match Method.of_string decoded.meth with
  | None -> Error ("Unsupported HTTP method: " ^ decoded.meth)
  | Some meth ->
      let req =
        Request.make ~meth ~url:decoded.url ~headers:(Headers.of_list decoded.headers)
          ~body:decoded.body ()
      in
      req
      |> fun request -> Worker.with_env request decoded.env
      |> fun request -> Worker.with_ctx request decoded.ctx
      |> fun request -> Worker.with_request_id request decoded.request_id
      |> fun request -> Worker.with_raw_env request decoded.request_id
      |> fun request -> Worker.with_raw_ctx request decoded.request_id
      |> fun request -> Ok request

let encode_response response =
  let body, body_base64 =
    match Response.body response with
    | Response.Body.Text value -> (value, None)
    | Response.Body.Bytes value -> ("", Some (bytes_to_base64 value))
  in
  {
    status = Status.code (Response.status response);
    headers = Response.headers response |> Headers.to_list;
    body;
    body_base64;
  }

let serve_async handler decoded =
  match decode_request decoded with
  | Ok request -> Async.map (Handler.run_async handler request) encode_response
  | Error message -> Response.text ~status:Status.bad_request message |> encode_response |> Async.return

let serve handler decoded = serve_async handler decoded |> Async.run
