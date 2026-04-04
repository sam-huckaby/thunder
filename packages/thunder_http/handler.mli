(** Opaque request handler. *)

type t
type handler = t

val handler : (Request.t -> Response.t) -> t
val handler_async : (Request.t -> Response.t Async.t) -> t
val run_async : t -> Request.t -> Response.t Async.t
val run : t -> Request.t -> Response.t
