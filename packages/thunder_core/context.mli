(** Typed immutable request-local context storage. *)

type t
(** Context map. *)

type 'a key
(** Typed key. Keys are unique by construction. *)

val empty : t
val key : unit -> 'a key
val add : t -> 'a key -> 'a -> t
val get : t -> 'a key -> 'a option
