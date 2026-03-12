(** Middleware composition helpers. *)

type t = Handler.t -> Handler.t
type middleware = t

val compose : t -> t -> t
val apply_many : t list -> Handler.t -> Handler.t

val recover : t
val logger : ?log:(string -> unit) -> unit -> t
val add_response_header : string -> string -> t
