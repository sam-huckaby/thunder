(** Request abstraction used by Thunder handlers. *)

type t

val make :
  meth:Method.t ->
  url:string ->
  headers:Headers.t ->
  body:string ->
  ?context:Thunder_core.Context.t ->
  unit ->
  t

val with_param : t -> string -> string -> t
val with_context : t -> Thunder_core.Context.t -> t
val context_map : t -> Thunder_core.Context.t

val meth : t -> Method.t
val url : t -> string
val path : t -> string

val header : t -> string -> string option
val headers : t -> Headers.t

val query : t -> string -> string option
val queries : t -> string -> string list

val cookie : t -> string -> string option
val param : t -> string -> string option

val body_string : t -> string
val body_bytes : t -> bytes

val context : t -> 'a Thunder_core.Context.key -> 'a option
