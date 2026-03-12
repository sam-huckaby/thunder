(** Normalized header name + value pair. *)

type t

val make : string -> string -> t
val name : t -> string
val value : t -> string
val normalized_name : string -> string
