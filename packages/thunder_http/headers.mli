(** Header collection preserving repeated values. Lookups are case-insensitive. *)

type t

val empty : t
val of_list : (string * string) list -> t
val to_list : t -> (string * string) list

val get : t -> string -> string option
val get_all : t -> string -> string list

val set : t -> string -> string -> t
val add : t -> string -> string -> t
val remove : t -> string -> t
