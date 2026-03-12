(** Cookie parsing and Set-Cookie serialization helpers. *)

type same_site = Strict | Lax | None_

type set

val make_set :
  ?path:string ->
  ?domain:string ->
  ?max_age:int ->
  ?expires:string ->
  ?secure:bool ->
  ?http_only:bool ->
  ?same_site:same_site ->
  string ->
  string ->
  set

val serialize_set : set -> string
val parse_request_header : string -> (string * string) list
val get : (string * string) list -> string -> string option
