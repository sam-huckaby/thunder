(** Response abstraction returned by Thunder handlers. *)

module Body : sig
  type t = Text of string | Bytes of bytes

  val text : string -> t
  val bytes : bytes -> t
end

type t

val empty : ?status:Status.t -> unit -> t

val text : ?status:Status.t -> string -> t
val bytes : ?status:Status.t -> ?content_type:string -> bytes -> t
val html : ?status:Status.t -> string -> t
val json : ?status:Status.t -> string -> t
val redirect : ?status:Status.t -> string -> t

val with_header : t -> string -> string -> t
val add_header : t -> string -> string -> t
val with_cookie : t -> Cookie.set -> t
val with_status : t -> Status.t -> t

val status : t -> Status.t
val headers : t -> Headers.t
val body : t -> Body.t
val body_string : t -> string
