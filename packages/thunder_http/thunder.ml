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

let handler = Handler.handler

let get = Router.get
let post = Router.post
let put = Router.put
let patch = Router.patch
let delete = Router.delete
let router = Router.router

let text = Response.text
let html = Response.html
let json = Response.json
let redirect = Response.redirect

let logger = Middleware.logger
let recover = Middleware.recover
