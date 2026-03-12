(** HTTP methods supported by Thunder MVP. *)

type t =
  | GET
  | POST
  | PUT
  | PATCH
  | DELETE
  | HEAD
  | OPTIONS

val equal : t -> t -> bool
val of_string : string -> t option
val to_string : t -> string
