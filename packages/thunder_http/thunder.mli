(** Public Thunder API surface. *)

module Method = Method
module Status = Status
module Headers = Headers
module Cookie = Cookie
module Query = Query
module Context = Thunder_core.Context
module Request = Request
module Response = Response
module Handler = Handler
module Middleware = Middleware
module Router = Router
module Worker = Worker

type handler = Handler.t
type middleware = Middleware.t

val handler : (Request.t -> Response.t) -> handler

val get : string -> handler -> Router.route
val post : string -> handler -> Router.route
val put : string -> handler -> Router.route
val patch : string -> handler -> Router.route
val delete : string -> handler -> Router.route
val router : Router.route list -> handler

val text : ?status:Status.t -> string -> Response.t
val html : ?status:Status.t -> string -> Response.t
val json : ?status:Status.t -> string -> Response.t
val redirect : ?status:Status.t -> string -> Response.t

val logger : ?log:(string -> unit) -> unit -> middleware
val recover : middleware
