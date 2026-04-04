(** Minimal async abstraction used by Thunder internals. *)

type 'a t

val return : 'a -> 'a t
val fail : exn -> 'a t
val make : ((('a, exn) result -> unit) -> unit) -> 'a t
val bind : 'a t -> ('a -> 'b t) -> 'b t
val map : 'a t -> ('a -> 'b) -> 'b t
val catch : 'a t -> (exn -> 'a t) -> 'a t
val respond : 'a t -> (('a, exn) result -> unit) -> unit
val run : 'a t -> 'a
