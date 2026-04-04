(** Public Thunder API surface. *)

module Method = Method
module Status = Status
module Headers = Headers
module Cookie = Cookie
module Query = Query
module Context = Thunder_core.Context
module Request = Request
module Response = Response
module Async = Async
module Handler = Handler
module Middleware = Middleware
module Router = Router
module Worker : sig
  include module type of Worker

  module KV = Thunder_worker_js.KV
  module R2 = Thunder_worker_js.R2
  module D1 = Thunder_worker_js.D1
  module Queues = Thunder_worker_js.Queues
  module AI = Thunder_worker_js.AI
  module Service = Thunder_worker_js.Service
  module Durable_object = Thunder_worker_js.Durable_object
  module Generic = Thunder_worker_js.Generic
end

type handler = Handler.t
type middleware = Middleware.t

val handler : (Request.t -> Response.t) -> handler
val handler_async : (Request.t -> Response.t Async.t) -> handler

val get : string -> handler -> Router.route
val post : string -> handler -> Router.route
val put : string -> handler -> Router.route
val patch : string -> handler -> Router.route
val delete : string -> handler -> Router.route
val router : Router.route list -> handler

val text : ?status:Status.t -> string -> Response.t
val bytes : ?status:Status.t -> ?content_type:string -> bytes -> Response.t
val html : ?status:Status.t -> string -> Response.t
val json : ?status:Status.t -> string -> Response.t
val redirect : ?status:Status.t -> string -> Response.t

val logger : ?log:(string -> unit) -> unit -> middleware
val recover : middleware
