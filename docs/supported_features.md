# Supported Features

## Support Matrix

| Area | Status | Notes |
| --- | --- | --- |
| Methods/status/headers/cookies/query | Supported | Transport-agnostic HTTP primitives |
| Buffered request/response bodies | Supported | Buffered runtime boundary |
| Router static + `:param` patterns | Supported | No splats |
| Middleware (`logger`, `recover`, header injection) | Supported | Deterministic composition order |
| Worker env/ctx attachment | Supported | Exposed via request context |
| Preview publish on build | Supported | Hash-based skip and metadata persistence |
| Production deploy | Supported | Explicit `@deploy-prod` + confirmation guard |
| Streaming responses | Not supported | Thunder uses buffered responses |
| Multipart forms | Not supported | No multipart parser |
| WebSockets | Not supported | No WebSocket API |
| Cloudflare binding wrappers via `Thunder.Worker.*` | Supported | KV, R2, D1, Queues, Workers AI, service bindings, Durable Objects, plus generic invoke |
| Static assets pipeline | Not supported | No built-in static assets flow |

## Supported

- HTTP methods and statuses
- header and cookie helpers
- query parsing with repeated key support
- buffered request/response body handling
- router with static and named params
- middleware (`logger`, `recover`, header injection)
- Worker env and ctx attachment through request context
- Cloudflare binding wrappers through `Thunder.Worker.*`
- preview publish on `dune build`
- explicit production deploy through `@deploy-prod`

## Not Supported

- streaming responses
- multipart form parsing
- WebSockets
- static assets pipeline

## Current Limits

- buffered body only
- no streaming API
- no multipart parser
- no WebSockets
- Cloudflare Workers target only
- Cloudflare binding wrappers are exposed through `Thunder.Worker.*`, with JS-only implementation details still living under `thunder.worker_js`
- AI support is buffered and non-streaming; streaming remains deferred
