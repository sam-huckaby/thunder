(** Response abstraction returned by Thunder handlers. *)

type t

val empty : ?status:Status.t -> unit -> t

val text : ?status:Status.t -> string -> t
val html : ?status:Status.t -> string -> t
val json : ?status:Status.t -> string -> t
val redirect : ?status:Status.t -> string -> t

val with_header : t -> string -> string -> t
val add_header : t -> string -> string -> t
val with_cookie : t -> Cookie.set -> t
val with_status : t -> Status.t -> t

val status : t -> Status.t
val headers : t -> Headers.t
val body_string : t -> string
