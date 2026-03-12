# Supported Features (MVP)

## Support matrix

| Area | Status | Notes |
|---|---|---|
| Methods/status/headers/cookies/query | Supported | Transport-agnostic HTTP primitives |
| Buffered request/response bodies | Supported | Buffered only in MVP |
| Router static + `:param` patterns | Supported | No splats in MVP |
| Middleware (`logger`, `recover`, header injection) | Supported | Deterministic composition order |
| Worker env/ctx attachment | Supported | Exposed via request context |
| Preview publish on build | Supported | Hash-based skip and metadata persistence |
| Production deploy | Supported | Explicit `@deploy-prod` + confirmation guard |
| Streaming responses | Deferred | Post-MVP |
| Multipart forms | Deferred | Post-MVP |
| WebSockets | Deferred | Post-MVP |
| Durable Objects/KV/D1 convenience APIs | Deferred | Post-MVP |
| Static assets pipeline | Deferred | Post-MVP |

## Supported

- HTTP methods and statuses
- Header and cookie helpers
- Query parsing with repeated key support
- Buffered request/response body handling
- Router with static + named params
- Middleware (`logger`, `recover`, header injection)
- Worker env/ctx attachment through request context
- Preview publish flow on `dune build`

## Deferred

- Streaming responses
- Multipart form parsing
- WebSockets
- Durable Objects conveniences
- KV/D1 convenience wrappers
- Static assets pipeline

## MVP limitations

- Buffered body only
- No streaming API
- No multipart parser
- No WebSockets
- Cloudflare Workers target only
