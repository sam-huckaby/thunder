(** Router with static and named-parameter path matching. *)

type route
type t

val get : string -> Handler.t -> route
val post : string -> Handler.t -> route
val put : string -> Handler.t -> route
val patch : string -> Handler.t -> route
val delete : string -> Handler.t -> route

val make : route list -> t
val dispatch : t -> Request.t -> Handler.t option * Request.t
val router : route list -> Handler.t
