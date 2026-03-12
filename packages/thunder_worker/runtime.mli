(** Runtime bridge between worker ABI fields and Thunder handlers. *)

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

val decode_request : decoded_request -> (Request.t, string) result
val encode_response : Response.t -> encoded_response
val serve : Handler.t -> decoded_request -> encoded_response
