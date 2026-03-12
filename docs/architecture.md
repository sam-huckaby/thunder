# Thunder Architecture

## Package layout

- `thunder_core`: shared typed context primitives.
- `thunder_http`: HTTP method/status/headers/query/cookie/request/response + handler/middleware.
- `thunder_router`: route parsing and dispatch.
- `thunder_worker`: Worker env/ctx bridging + runtime adapter.
- `thunder_cli`: preview and production deployment orchestration.

## Request lifecycle

Cloudflare `fetch(request, env, ctx)` -> JS host -> Thunder runtime decode -> OCaml handler/router/middleware -> response encode -> JS `Response`.

## Runtime boundary

MVP uses buffered requests and buffered responses only. No streaming ABI is exposed.

## ABI shape (MVP)

Thunder uses a JSON ABI payload at the JS <-> Wasm boundary.

Request payload (`v=1`):

- `v`: ABI version number (`1`)
- `method`: HTTP method string (must parse to `Thunder.Method`)
- `url`: full request URL
- `headers`: `(name, value) list`, preserving repeated header names
- `body_base64`: buffered request body encoded as base64
- `env_bindings`: `(name, value) list` for serializable env values
- `ctx_features`: string list of recognized ctx capabilities (for MVP: `waitUntil`, `passThroughOnException`)

Response payload:

- `status`: numeric status code
- `headers`: `(name, value) list`, preserving repeated values including `set-cookie`
- `body` or `body_base64`: buffered response body

## Validation and failure behavior

- Unknown request method yields explicit `400` response from runtime adapter.
- Malformed response payload from Wasm yields explicit `500` from JS runtime.
- Missing required ABI exports in Wasm (`thunder_handle_json` or `thunder_handle_fetch_json`) yields explicit `500` with available export names.
- Non-Wasm artifacts at the configured Wasm path fail with a clear initialization error.

## Why no streaming in MVP

Thunder intentionally keeps the runtime boundary buffered in MVP to keep the Wasm ABI simple and deterministic while request/response contracts stabilize. Streaming support is deferred to post-MVP so the core API, router semantics, middleware ordering, and deployment flow can remain small and reliable first.
