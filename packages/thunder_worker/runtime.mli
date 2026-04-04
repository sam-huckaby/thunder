(** Runtime bridge between worker ABI fields and Thunder handlers. *)

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

val decode_request : decoded_request -> (Request.t, string) result
val encode_response : Response.t -> encoded_response
val serve_async : Handler.t -> decoded_request -> encoded_response Async.t
val serve : Handler.t -> decoded_request -> encoded_response
