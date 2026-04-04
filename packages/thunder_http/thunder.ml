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
module Worker = struct
  include Worker

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

let handler = Handler.handler
let handler_async = Handler.handler_async

let get = Router.get
let post = Router.post
let put = Router.put
let patch = Router.patch
let delete = Router.delete
let router = Router.router

let text = Response.text
let bytes = Response.bytes
let html = Response.html
let json = Response.json
let redirect = Response.redirect

let logger = Middleware.logger
let recover = Middleware.recover
