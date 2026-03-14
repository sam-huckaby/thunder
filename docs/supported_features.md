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
| Durable Objects/KV/D1 convenience APIs | Not supported | No convenience wrappers yet |
| Static assets pipeline | Not supported | No built-in static assets flow |

## Supported

- HTTP methods and statuses
- header and cookie helpers
- query parsing with repeated key support
- buffered request/response body handling
- router with static and named params
- middleware (`logger`, `recover`, header injection)
- Worker env and ctx attachment through request context
- preview publish on `dune build`
- explicit production deploy through `@deploy-prod`

## Not Supported

- streaming responses
- multipart form parsing
- WebSockets
- Durable Objects convenience helpers
- KV and D1 convenience wrappers
- static assets pipeline

## Current Limits

- buffered body only
- no streaming API
- no multipart parser
- no WebSockets
- Cloudflare Workers target only
