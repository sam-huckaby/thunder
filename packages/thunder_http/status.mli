(** HTTP status values. *)

type t

val make : int -> string -> t
val code : t -> int
val reason : t -> string

val ok : t
val created : t
val no_content : t
val moved_permanently : t
val found : t
val bad_request : t
val not_found : t
val method_not_allowed : t
val internal_server_error : t
