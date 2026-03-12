(** Query string parser preserving repeated keys. *)

type t

val empty : t
val parse : string -> t
val get : t -> string -> string option
val get_all : t -> string -> string list
val to_list : t -> (string * string) list
