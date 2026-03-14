# Thunder Architecture

## Package layout

- `thunder_core`: shared typed context primitives.
- `thunder_http`: HTTP method/status/headers/query/cookie/request/response + handler/middleware.
- `thunder_router`: route parsing and dispatch.
- `thunder_worker`: Worker env/ctx bridging + runtime adapter.
- `thunder_cli`: preview and production deployment orchestration.

For the planned separation between framework internals and generated app code, see `docs/framework_boundary.md` and `PLAN2.md`.

## Request lifecycle

Cloudflare `fetch(request, env, ctx)` -> JS host -> Thunder runtime decode -> OCaml handler/router/middleware -> response encode -> JS `Response`.

## Runtime boundary

MVP uses buffered requests and buffered responses only. No streaming ABI is exposed.

Thunder is now moving toward a Thunder-owned runtime ABI for edge apps. The first production-ready rollout of that ABI remains JSON-based so the contract is explicit, testable, and portable even while the underlying compiler/runtime implementation evolves.

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

## ABI evolution direction

Thunder's long-term runtime contract is shifting away from compiler side effects and toward a versioned framework-owned ABI.

Planned steady-state shape:

- `init(init_payload) -> init_result`
- `handle(request_payload) -> response_payload`
- versioned ABI independent from Thunder package version
- JSON payloads for the first production-ready rollout
- manifest-driven artifact packaging for preview and production deploys

This means:

- the Cloudflare Worker host stays thin and Worker-specific
- Thunder owns the runtime contract presented to app code
- compiler-generated JS/Wasm artifacts remain implementation details behind a Thunder shim
- preview and production deploys use the same staged deploy tree shape
- `dist/worker/manifest.json` is the source of truth for staged runtime artifacts
- the runtime boundary stays behind `worker_runtime/app_abi.mjs`, not in the host itself

Current runtime shape:

- `worker_runtime/index.mjs`: thin Cloudflare Worker host
- `worker_runtime/app_abi.mjs`: Thunder-owned runtime shim for the single supported runtime path
- `worker_runtime/compiled_runtime_backend.mjs`: compiled runtime loader that wires the staged JS/Wasm artifacts into the host

## ABI v2 target contract

Thunder ABI v2 remains JSON-based for the first production-ready rollout.

Init payload:

- `abi_version`: integer ABI version expected by the host/shim
- `asset_base_url`: optional string base URL used for artifact resolution
- `app_id`: stable string identifier for the staged app/runtime bundle
- `expected_capabilities`: string list of capabilities the host expects the runtime to support

Init result:

- `abi_version`: integer ABI version actually activated
- `app_id`: string identifier echoed back by the runtime
- `asset_base_url`: optional resolved asset base URL
- `capabilities`: string list describing enabled runtime features

Request payload (`handle`):

- `v`: ABI request payload version number (`1` in the current JSON request format)
- `method`: HTTP method string
- `url`: full request URL
- `headers`: `(name, value) list`, preserving repeated names in arrival order
- `body`: decoded buffered body string when representable as text
- `body_base64`: buffered body encoded as base64 for binary-safe transfer
- `env_bindings`: `(name, value) list` for serializable Worker env values
- `ctx_features`: string list describing recognized Worker execution-context capabilities

Response payload (`handle`):

- `status`: numeric HTTP status code
- `headers`: `(name, value) list`, preserving repeated values including `set-cookie`
- exactly one of `body` or `body_base64`

Versioning notes:

- Thunder ABI versioning is independent from Thunder package versioning.
- The Phase 14 migration keeps request/response payloads JSON-based even as the runtime lifecycle shifts to explicit `init` + `handle` entrypoints.
- Unsupported ABI versions must fail explicitly before request handling begins.
- The runtime shim may derive default init metadata such as `app_id` and `asset_base_url` from the staged manifest.
- The host no longer probes compiler globals directly; the shim owns the single compiled-runtime path.

## Validation and failure behavior

- Unknown request method yields explicit `400` response from runtime adapter.
- Malformed response payload from Wasm yields explicit `500` from JS runtime.
- Missing required ABI exports in Wasm (`thunder_handle_json` or `thunder_handle_fetch_json`) yields explicit `500` with available export names.
- Non-Wasm artifacts at the configured Wasm path fail with a clear initialization error.

## ABI error taxonomy

- `init_failure`: runtime could not initialize or load staged artifacts.
- `abi_version_mismatch`: host/shim and runtime disagree on ABI version.
- `request_decode_failure`: incoming request payload could not be decoded into Thunder request state.
- `app_execution_failure`: Thunder handler/router/middleware raised or returned an unrecoverable runtime error.
- `response_decode_failure`: runtime returned malformed response payload.

User-facing behavior rules:

- initialization failures return explicit `500` responses with actionable diagnostics
- decode/ABI mismatch failures fail clearly and early
- handler execution failures route through Thunder recovery behavior where configured
- response decode failures are treated as runtime invocation failures, not silent fallbacks

## Why no streaming in MVP

Thunder intentionally keeps the runtime boundary buffered in MVP to keep the Wasm ABI simple and deterministic while request/response contracts stabilize. Streaming support is deferred to post-MVP so the core API, router semantics, middleware ordering, and deployment flow can remain small and reliable first.
