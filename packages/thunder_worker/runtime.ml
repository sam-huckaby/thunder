type decoded_request = {
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
}

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
      |> fun request -> Ok request

let encode_response response =
  {
    status = Status.code (Response.status response);
    headers = Response.headers response |> Headers.to_list;
    body = Response.body_string response;
  }

let serve handler decoded =
  match decode_request decoded with
  | Ok request -> Handler.run handler request |> encode_response
  | Error message -> Response.text ~status:Status.bad_request message |> encode_response
