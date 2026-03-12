(** Opaque request handler. *)

type t
type handler = t

val handler : (Request.t -> Response.t) -> t
val run : t -> Request.t -> Response.t
