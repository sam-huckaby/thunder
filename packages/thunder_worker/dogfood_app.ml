let app =
  Router.router
    [
      Router.get "/"
        (Handler.handler (fun _ ->
             Response.html
               "<html><head><meta charset=\"utf-8\" /><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" /><title>Thunder</title><style>html,body{height:100%;margin:0}body{display:grid;place-items:center;background:#fff;color:#111;font-family:ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif}h1{margin:0;font-size:clamp(1.75rem,4vw,3rem);font-weight:600;letter-spacing:0.01em}</style></head><body><h1>Welcome to the storm</h1></body></html>"));
      Router.get "/health" (Handler.handler (fun _ -> Response.json "{\"ok\":true}"));
    ]
  |> Middleware.recover
