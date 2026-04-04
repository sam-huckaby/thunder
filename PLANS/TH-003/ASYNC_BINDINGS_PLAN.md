---
id: TH-003
title: Thunder Async Handlers + Full Cloudflare Async Bindings
status: in_progress
type: feature
priority: high
owner: null
created: 2026-03-28
updated: 2026-03-28
related_plans:
  - TH-000
  - TH-001
  - TH-002
depends_on: []
blocks: []
labels:
  - async
  - cloudflare-bindings
  - runtime
  - zephyr
  - interoperability
---

# Thunder Async Handlers + Full Cloudflare Async Bindings (Zephyr + Standalone)

## Goal

Upgrade Thunder so apps can use Cloudflare's async binding model directly from OCaml while preserving Thunder's current framework-owned Worker boundary.

Target outcomes:

- async handlers, middleware, router dispatch, and runtime entrypoints
- request-scoped access to all Cloudflare bindings without collapsing the JSON ABI boundary
- binary response bodies via a first-class body model and `body_base64` support
- useful standalone Worker apps plus clear Zephyr interoperability

## Current State

Thunder currently uses a Thunder-owned, versioned JSON ABI between the JS Worker host in `worker_runtime/` and the compiled OCaml runtime exposed as `globalThis.thunder_handle_json`.

Today:

- request and response flow are buffered and JSON-shaped
- `env_bindings` only serializes primitive binding values (`string`, `number`, `boolean`)
- raw Worker host objects are not passed into OCaml
- handler, middleware, router, and runtime execution are synchronous
- response bodies are string-only on the OCaml side even though the JS host can decode `body_base64`

This means Thunder can preserve a clean runtime boundary today, but it cannot yet express normal Cloudflare binding usage patterns such as KV, R2, Durable Objects, D1, Queues, service bindings, or Workers AI from OCaml.

## Non-goals For This Plan

- remove Thunder's JSON ABI boundary and pass arbitrary host objects directly through the wire format
- add streaming response support in the first async release
- add new runtime platforms beyond Cloudflare Workers
- require Zephyr to use Thunder's binding support
- make Workers AI streaming a first-class Thunder response path before buffered async support lands cleanly

## Product Principles

1. Keep the Worker host boundary framework-owned and versioned.
2. Make async the internal truth while preserving a compatibility path for existing sync apps.
3. Keep binding access request-scoped to avoid stale global binding state.
4. Prefer safe, typed wrapper APIs first, with a raw escape hatch for advanced users.
5. Keep standalone Thunder apps first-class even while adding Zephyr interop examples.
6. Treat binary payloads as a real framework concern rather than a JS-only edge case.

## Proposed End State

A Thunder app can:

- define async handlers naturally
- use Cloudflare bindings from OCaml through typed wrapper modules
- still run old sync handlers unchanged through automatic lifting
- return text or bytes bodies through the same Thunder response API
- stay behind Thunder's owned Worker host and ABI negotiation path

Representative use cases that should work in-repo:

- KV get/put for text and bytes
- R2 get/put for buffered content
- Durable Object call-by-name through a per-request stub cache
- Queue send and a minimal consumer example
- D1 prepare/bind/first/all/raw/run
- service binding fetch and RPC-style calls
- Workers AI non-streaming inference
- Zephyr-oriented diagnostic examples using `ze_env`, `ze_files`, and `ze_snapshots`

## Required Architecture Shift

Thunder should keep the JSON ABI and add a request-scoped host-context side channel.

Target shape:

- the Worker host stores raw `env` and `ctx` in request-local state
- OCaml reads request-local raw host objects through host-installed getters
- typed wrapper APIs call a single host RPC surface for binding operations
- advanced users can still access raw binding objects via an explicit escape hatch

### Request context strategy

Use `AsyncLocalStorage` as the primary strategy and a request-id keyed `Map` fallback when ALS is unavailable.

| Strategy | Pros | Cons | When used |
|---|---|---|---|
| AsyncLocalStorage | Automatic propagation through nested `await`; clean `run` + `getStore` semantics | Requires `nodejs_als` or `nodejs_compat` | Default and recommended |
| request-id + Map | Works without Node APIs | Requires carrying `request_id`; cleanup must always happen in `finally` | Fallback for unsupported environments |

## API And Runtime Decisions

### ABI capability additions

Add explicit capabilities:

- `async_handlers`
- `request_context_raw_env`
- `request_context_raw_ctx`
- `binding_rpc`
- `binary_response_payload`

Keep existing capabilities for backward compatibility.

### Request payload compatibility

Support both payload versions during rollout:

- `v=1` keeps current behavior
- `v=2` adds `request_id` and becomes the default path for async binding access

Target `v=2` shape:

```jsonc
{
  "v": 2,
  "request_id": "uuid",
  "method": "GET",
  "url": "https://...",
  "headers": [["name", "value"]],
  "body": "...",
  "body_base64": "...",
  "env_bindings": [["NAME", "value"]],
  "ctx_features": ["waitUntil"]
}
```

### Response payload compatibility

Upgrade OCaml response encoding so it can emit either text or binary output:

```jsonc
{
  "status": 200,
  "headers": [["content-type", "..."]],
  "body": "...",
  "body_base64": "..."
}
```

`body` and `body_base64` must be mutually exclusive.

### Async framework model

Make async the single internal truth:

- `Handler.t = Request.t -> Response.t Async.t`
- `Middleware.t = Handler.t -> Handler.t`
- router dispatch resolves handlers asynchronously
- runtime and entrypoint APIs return promise-backed results

Compatibility rules:

- keep `Thunder.handler` as the sync helper that lifts with `Async.return`
- add `Thunder.handler_async`
- update built-in middleware to catch both sync exceptions and async failures

### Response body model

Introduce a first-class body type:

```ocaml
module Body : sig
  type t = Text of string | Bytes of bytes
  val text : string -> t
  val bytes : bytes -> t
end
```

Update `Response.t` to carry `Body.t` and add `Response.bytes` while keeping existing text/html/json/redirect helpers.

### Worker binding access surface

Keep primitive env access and add raw/object access plus typed wrappers.

New low-level APIs:

- `Worker.raw_env : Request.t -> Js_of_ocaml.Js.Unsafe.any option`
- `Worker.raw_ctx : Request.t -> Js_of_ocaml.Js.Unsafe.any option`
- `Worker.binding_any : Request.t -> string -> Js_of_ocaml.Js.Unsafe.any option`

Wrapper modules to add:

- `Worker.KV`
- `Worker.R2`
- `Worker.DO`
- `Worker.Queues`
- `Worker.D1`
- `Worker.Service`
- `Worker.AI`

## Phase A1 - Async runtime contract

## Goal

Define the async execution contract and the request-scoped host-context model without implementing all binding wrappers yet.

## Tasks

### A1.1 Freeze async framework direction

Document that async becomes the internal truth for:

- handlers
- middleware
- router dispatch
- Worker runtime entrypoints

Acceptance:

- docs and plan consistently describe async as the internal execution model
- compatibility behavior for sync handlers is explicitly defined

### A1.2 Freeze request-scoped host context direction

Document the request-local raw host-object strategy:

- `env` and `ctx` live in request-local JS state
- OCaml reads them through explicit getters
- binding operations flow through a single host RPC entrypoint

Acceptance:

- no plan section implies raw host objects travel through the JSON payload itself
- request-scoped design is documented as mandatory

### A1.3 Freeze request context strategy order

Choose and document:

1. AsyncLocalStorage as primary
2. request-id Map as fallback
3. optional explicit override for tests/debugging

Acceptance:

- fallback behavior is unambiguous
- cleanup requirements are documented for the Map path

### A1.4 Freeze ABI compatibility rules

Need:

- `v=1` support during rollout
- `v=2` as the new request payload default
- new capability negotiation fields for async and binding RPC support

Acceptance:

- request/response compatibility story is documented
- required capability names are fixed for implementation

### A1.5 Add checkpoint note

## Checkpoint: A1 complete
Completed:
- froze async-first execution as the internal direction for handlers, middleware, router dispatch, and runtime entrypoints
- documented the request-scoped host-context model as the required path for raw Worker `env` and `ctx` access
- fixed the request-context strategy order around AsyncLocalStorage primary plus request-id Map fallback
- fixed ABI rollout rules around `v=1` compatibility, `v=2` request payloads, and explicit async/binding capability names

Verified:
- `PLANS/TH-003/ASYNC_BINDINGS_PLAN.md` now defines the execution, request-context, and compatibility contract for the async bindings work
- `docs/architecture.md` now documents the request-context side channel, request payload v2 shape, and capability negotiation updates

Next:
- begin A2 by implementing request-local host context and ABI v2 plumbing

---

## Phase A2 - Request context and ABI v2 host plumbing

## Goal

Teach the JS Worker host to create request-local context, expose raw host getters, and emit ABI request payload v2.

## Tasks

### A2.1 Add `worker_runtime/request_context.mjs`

Need:

- request context strategy selection
- `enterRequestContext` / `exit` lifecycle
- global getters for request-local `env` and `ctx`

Acceptance:

- ALS path works when supported
- Map fallback works when ALS is unavailable

### A2.2 Wrap fetch handling in request-local context

Update `worker_runtime/index.mjs` so each request:

- enters request context before runtime invocation
- exits in `finally`
- keeps request-local data isolated under concurrency

Acceptance:

- no request leaks context into the next request
- cleanup happens even on runtime init or handler failure

### A2.3 Emit request payload v2

Need:

- generated `request_id`
- current `body` and `body_base64` fields preserved
- existing primitive `env_bindings` extraction preserved

Acceptance:

- host emits valid `v=2` payloads
- current config-style primitive binding behavior remains intact

### A2.4 Extend `app_abi.mjs` capability handling

Need:

- new advertised capabilities
- init-time expected-capability validation
- surfaced selected request-context strategy in init result

Acceptance:

- unsupported capability requirements fail fast with clear errors

### A2.5 Add JS tests for request context

Test:

- ALS nested await propagation
- Map fallback request-id lookup
- cleanup on success and failure
- concurrent isolation

### A2.6 Add checkpoint note

## Checkpoint: A2 complete
Completed:
- added `worker_runtime/request_context.mjs` with AsyncLocalStorage primary support, request-id Map fallback, and global raw `env` / `ctx` getters
- updated `worker_runtime/index.mjs` to enter and exit request-local context per request, emit ABI request payload `v=2`, and send request-context capability requirements through init payloads
- updated `worker_runtime/app_abi.mjs` to advertise async/binding capabilities, validate expected capabilities, and surface the selected request-context strategy in init results
- updated `packages/thunder_worker/entry.ml` to accept ABI request payload version `2` during rollout while preserving `v=1` compatibility

Verified:
- `node --test worker_runtime/index_test.mjs`
- `opam exec -- dune build packages/thunder_worker/wasm_entry.bc`

Next:
- begin A3 by converting Thunder's OCaml execution stack to async-first internals

---

## Phase A3 - Async OCaml handler stack

## Goal

Convert Thunder's OCaml execution model from sync-first to async-first while keeping sync app compatibility.

## Tasks

### A3.1 Add `Thunder.Async`

Need:

- core async type
- `return`, `bind`, `map`, and `catch`
- clear implementation strategy for JS promise interop

Acceptance:

- async abstraction is stable enough for framework internals

### A3.2 Convert handler internals to async

Need:

- `Handler.t` becomes async-first
- `Thunder.handler` lifts sync handlers
- `Thunder.handler_async` is added for native async code

Acceptance:

- existing sync handlers still compile and behave the same
- async handlers can return promise-backed responses

### A3.3 Convert middleware to async-aware composition

Need:

- built-in middleware composes async handlers cleanly
- `recover` catches both thrown exceptions and rejected async flows

Acceptance:

- composition order stays stable
- failure handling remains predictable

### A3.4 Convert router dispatch to async

Need:

- matching logic stays unchanged
- dispatch and run paths become async-aware

Acceptance:

- route precedence and param extraction remain unchanged
- 404 and match behavior stay correct

### A3.5 Convert Worker runtime entrypoints to async

Need:

- runtime serve path returns async response payloads
- exported `thunder_handle_json` supports async completion

Acceptance:

- JS host can await the runtime without compatibility regressions

### A3.6 Add OCaml tests for async semantics

Test:

- sync handler lifting
- async middleware order
- `recover` over sync and async failures
- router correctness under async dispatch

### A3.7 Add checkpoint note

## Checkpoint: A3 complete
Completed:
- added `packages/thunder_http/async.ml` and `packages/thunder_http/async.mli` as the first framework-owned async abstraction
- converted `Handler.t` to the async-first internal shape while preserving `Handler.run` and `Thunder.handler` as sync-compatible helpers
- added `Handler.handler_async`, `Handler.run_async`, `Thunder.Async`, and `Thunder.handler_async`
- updated middleware, router, and runtime composition to operate over async-aware handlers while preserving existing sync behavior
- added `Runtime.serve_async` alongside the existing synchronous `Runtime.serve`

Verified:
- `opam exec -- dune build tests/unit_tests.exe tests/integration_tests.exe tests/example_smoke_tests.exe packages/thunder_worker/wasm_entry.bc`
- `opam exec -- dune exec ./tests/unit_tests.exe`
- `opam exec -- dune exec ./tests/integration_tests.exe`
- `opam exec -- dune exec ./tests/example_smoke_tests.exe`

Next:
- begin A4 by adding binary response body support and encoder updates

---

## Phase A4 - Binary response bodies and payload encoding

## Goal

Let Thunder represent and return binary response bodies through the existing Worker host boundary.

## Tasks

### A4.1 Introduce `Response.Body`

Need:

- `Text` and `Bytes` variants
- helper constructors for each variant

Acceptance:

- response body model is no longer string-only

### A4.2 Update response constructors

Need:

- keep existing text/html/json/redirect helpers
- add `Response.bytes`

Acceptance:

- existing response helpers keep current behavior
- bytes responses are easy to construct intentionally

### A4.3 Update OCaml response encoding

Need:

- emit `body` for text
- emit `body_base64` for bytes
- never emit both simultaneously

Acceptance:

- response encoder matches host expectations
- binary payload behavior is test-covered

### A4.4 Add binary response tests

Test:

- `Body.Text -> body`
- `Body.Bytes -> body_base64`
- host decoding reconstructs the intended bytes payload

### A4.5 Add checkpoint note

## Checkpoint: A4 complete
Completed:
- introduced `Response.Body` with `Text` and `Bytes` variants
- added `Response.bytes` and updated the response model so text and binary bodies share one framework-owned representation
- updated `Runtime.encode_response` to emit `body_base64` for bytes responses
- updated `packages/thunder_worker/entry.ml` so JSON response encoding emits `body` or `body_base64` based on the encoded response payload
- added unit coverage for bytes response encoding

Verified:
- `opam exec -- dune build tests/unit_tests.exe tests/integration_tests.exe tests/example_smoke_tests.exe packages/thunder_worker/wasm_entry.bc`
- `opam exec -- dune exec ./tests/unit_tests.exe`
- `node --test worker_runtime/index_test.mjs`

Next:
- begin A5 by introducing the binding RPC layer and raw binding access APIs

---

## Phase A5 - Binding RPC foundation and raw binding access

## Goal

Add the host RPC layer and the low-level OCaml APIs needed to call real Cloudflare bindings safely.

## Tasks

### A5.1 Add `worker_runtime/binding_rpc.mjs`

Need:

- a single allowlisted RPC entrypoint
- request-context lookup for `env` and `ctx`
- JSON-serializable success and error results

Acceptance:

- unknown ops fail clearly
- invalid arguments fail clearly

### A5.2 Add low-level Worker raw access APIs

Need:

- `raw_env`
- `raw_ctx`
- `binding_any`

Acceptance:

- advanced users can opt into raw interop explicitly
- typed wrappers can build on the same foundation

### A5.3 Add per-request caches where required

Need:

- especially Durable Object stub caching keyed by binding/name within one request

Acceptance:

- request-local ordering assumptions are preserved where practical
- no cache state leaks across requests

### A5.4 Define RPC error shaping rules

Need:

- stable success/error envelope
- predictable OCaml-side error decoding

Acceptance:

- wrapper modules can share one error handling model

### A5.5 Add JS tests for RPC safety

Test:

- allowlist enforcement
- argument validation
- request-local cache isolation

Progress note:

- `worker_runtime/binding_rpc.mjs` now exists as the first host RPC foundation and is loaded by the Worker host.
- runtime tests now cover unsupported-op and invalid-argument failures for the RPC surface.
- request-id plumbing now reaches OCaml request context through `Worker.request_id`, which gives the runtime a stable lookup key for request-scoped host operations.
- initial KV RPC support now exists for text/bytes `get`, `put`, and `delete` on the JS host, with request-context-backed tests covering both text and base64 bytes flows.
- binding RPC results are now normalized into shared success/error envelopes so later typed wrapper decoding can build on one host error model.
- low-level OCaml raw binding APIs are still conservative placeholders, and the next wrapper step needs a native-safe JS interop boundary so local OCaml test executables do not regress while async binding calls are added.
- a direct attempt to add OCaml-side KV wrappers inside the existing native-tested `thunder_worker` library regressed native test executables with js-of-ocaml runtime primitive failures, so the next wrapper iteration should isolate JS interop behind a JS-only boundary rather than linking it straight into the native test path.
- `packages/thunder_worker_js/` now exists as that JS-only boundary, with the first dedicated OCaml binding-RPC and KV wrapper modules living outside the core `thunder_worker` library so native test targets stay green.
- Workers AI is now the next supported host primitive on the JS side through `ai.run`, and the JS-only wrapper boundary now also exposes AI helpers plus a generic binding invocation path for Cloudflare primitives that Thunder has not wrapped yet.
- D1 is now also supported in the host RPC layer through `d1.query`, and the JS-only wrapper boundary now exposes `D1.first_json`, `D1.all_json`, `D1.raw_json`, and `D1.run_json` for JSON-first query flows.
- service bindings are now supported through `service.fetch`, and Durable Objects are now supported through `durable_object.call`, both exposed through `packages/thunder_worker_js/` without regressing native test executables.
- R2 is now supported through `r2.get` and `r2.put`, Queues are now supported through `queue.send` and `queue.send_batch`, and new example apps now demonstrate individual and combined Cloudflare primitive usage through the JS-only wrapper boundary.

### A5.6 Add checkpoint note

## Checkpoint: A5 complete
Completed:
- added `worker_runtime/binding_rpc.mjs` as the host-owned request-scoped binding RPC layer
- added request-id plumbing into OCaml request context through `Worker.request_id`
- standardized binding RPC success and error envelopes for host operations
- introduced `packages/thunder_worker_js/` as the JS-only OCaml wrapper boundary so binding wrappers do not regress native test executables
- added host RPC support for KV, R2, D1, Workers AI, service bindings, Durable Objects, Queues, and generic binding invocation

Verified:
- `node --test worker_runtime/index_test.mjs`
- `opam exec -- dune build packages/thunder_worker_js/thunder_worker_js.cma packages/thunder_worker_js/thunder_worker_js.cmxa`
- `opam exec -- dune exec ./tests/unit_tests.exe`
- `opam exec -- dune exec ./tests/integration_tests.exe`
- `opam exec -- dune exec ./tests/example_smoke_tests.exe`

Next:
- begin A6 by shipping typed binding wrappers and runnable examples

---

## Phase A6 - Typed binding wrappers and examples

## Goal

Ship the first supported Cloudflare binding wrappers and prove them through examples and tests.

## Tasks

### A6.1 Add `Worker.KV`

Need:

- `get_text`
- `get_bytes`
- `put_text`
- `put_bytes`
- `delete`
- `list`

Acceptance:

- text and bytes flows both work from OCaml

### A6.2 Add `Worker.R2`

Need:

- buffered `get_text`
- buffered `get_bytes`
- buffered `put_bytes`

Acceptance:

- basic object read/write works for standalone apps

### A6.3 Add `Worker.DO`

Need:

- call-by-name flow
- per-request stub reuse
- one documented RPC usage shape

Acceptance:

- a Durable Object example works end-to-end

### A6.4 Add `Worker.Queues`

Need:

- `send_json`
- `send_text`
- `send_bytes`
- `send_batch_json`

Acceptance:

- producer example works
- minimal consumer path is documented or included

### A6.5 Add `Worker.D1`

Need:

- `prepare`
- `bind`
- `first`
- `all`
- `raw`
- `run`

Acceptance:

- prepared statement and bound parameter flows are covered by tests/examples

### A6.6 Add `Worker.Service`

Need:

- `fetch`
- `rpc_call`

Acceptance:

- service binding example works through one supported inter-Worker flow

### A6.7 Add `Worker.AI`

Need:

- `run_json`
- `run_text`
- docs on non-streaming support and remote-only local development constraints

Acceptance:

- one non-streaming AI example works
- current streaming limitation is documented clearly

### A6.8 Add standalone examples

Examples should demonstrate:

- KV text and bytes
- R2 blob access
- Durable Object call
- Queue send
- D1 query
- service binding call
- AI inference

Acceptance:

- examples are runnable and referenced from docs

### A6.9 Add Zephyr interoperability example

Need:

- at least one example focused on `ze_env`, `ze_files`, and `ze_snapshots`
- clear note that Thunder does not own or assume Zephyr schemas

Acceptance:

- Thunder demonstrates Zephyr binding interoperability without coupling product design to Zephyr internals

### A6.10 Add checkpoint note

## Checkpoint: A6 complete
Completed:
- added JS-only wrapper modules under `packages/thunder_worker_js/` for KV, R2, D1, Queues, Workers AI, service bindings, Durable Objects, and a generic primitive helper
- exposed those wrappers through the `thunder.worker_js` package surface and began promoting them into the main Thunder API through `Thunder.Worker.*`
- added runnable examples for individual and grouped Cloudflare primitive usage in `examples/cloudflare_ai`, `examples/cloudflare_storage`, `examples/cloudflare_coordination`, `examples/cloudflare_full_stack`, and `examples/zephyr_kv_inspector`
- documented example binding names and `wrangler.toml` snippets in `docs/examples.md`
- documented Zephyr interoperability without coupling Thunder to Zephyr-owned schemas

Verified:
- `node --test worker_runtime/index_test.mjs`
- `opam exec -- dune build packages/thunder_worker_js/thunder_worker_js.cma packages/thunder_worker_js/thunder_worker_js.cmxa examples/cloudflare_ai/main.exe examples/cloudflare_storage/main.exe examples/cloudflare_coordination/main.exe examples/cloudflare_full_stack/main.exe examples/zephyr_kv_inspector/main.exe`
- `opam exec -- dune exec ./tests/unit_tests.exe`
- `opam exec -- dune exec ./tests/integration_tests.exe`
- `opam exec -- dune exec ./tests/example_smoke_tests.exe`

Next:
- begin A7 by hardening the async binding stack and expanding verification coverage

---

## Phase A7 - Verification, hardening, and rollout

## Goal

Harden the async binding stack, validate it under CI, and document the release constraints clearly.

## Tasks

### A7.1 Add integration coverage for simulated bindings

Need validation for:

- KV
- R2
- D1
- Queues
- Durable Objects
- service bindings where practical

Acceptance:

- integration path proves wrapper correctness against local binding simulation where supported

### A7.2 Add AI test strategy

Need:

- deterministic mock path for AI wrappers
- clear separation between local test strategy and remote real-binding validation

Acceptance:

- AI wrapper tests do not depend on live remote inference for routine CI

### A7.3 Add concurrency and leak tests

Test:

- ALS request isolation
- Map cleanup to zero after stress runs
- no cross-request contamination in caches or raw host access

Acceptance:

- request context behavior is stress-tested under concurrency

### A7.4 Update architecture and contributor docs

Need updates for:

- request v2 payload
- request context side channel
- async handler model
- binary responses
- required Wrangler flags such as `nodejs_als`
- known buffered-only limitations

Acceptance:

- docs describe the shipped model, not the old sync-only path

### A7.5 Add release checklist updates

Release notes should call out:

- async handler support
- `Response.Body`
- binding wrappers
- raw binding access
- buffered-only limitations
- AI streaming as deferred / escape-hatch only

Acceptance:

- release checklist and release notes reflect the new runtime model

### A7.6 Add final checkpoint note

## Checkpoint: A7 complete
Completed:
- expanded `worker_runtime/index_test.mjs` with concurrency and cleanup coverage for ALS isolation, Map cleanup after failures, and Map stress runs under concurrent fetches
- documented the AI test strategy around mocked host RPC coverage in CI and explicit real-binding validation outside routine CI
- updated architecture, deployment, examples, supported-features, and release-checklist docs to reflect the shipped async binding model, Wrangler `nodejs_als` guidance, buffered response limits, and release-facing binding/runtime notes
- updated `scripts/verify_generated_app_fixture.sh` so generated-app verification now compiles a fixture route using `Thunder.Worker.KV`, `R2`, `D1`, `Queues`, `AI`, `Service`, `Durable_object`, and `Generic`
- finalized A5/A6/A7 plan checkpoints so the async binding stack, JS-only wrapper boundary, and example coverage are recorded as the current Thunder direction

Verified:
- `node --test worker_runtime/index_test.mjs`
- `opam exec -- dune build packages/thunder_worker_js/thunder_worker_js.cma packages/thunder_worker_js/thunder_worker_js.cmxa examples/cloudflare_ai/main.exe examples/cloudflare_storage/main.exe examples/cloudflare_coordination/main.exe examples/cloudflare_full_stack/main.exe examples/zephyr_kv_inspector/main.exe packages/thunder_worker/wasm_entry.bc tests/unit_tests.exe tests/integration_tests.exe tests/example_smoke_tests.exe`
- `opam exec -- dune exec ./tests/unit_tests.exe`
- `opam exec -- dune exec ./tests/integration_tests.exe`
- `opam exec -- dune exec ./tests/example_smoke_tests.exe`

Next:
- treat async bindings and binary responses as the canonical Thunder runtime path

---

## Cross-cutting Risks

- async refactor touches `Handler`, `Middleware`, `Router`, `Runtime`, and entrypoint code at once
- request-id Map fallback can leak if cleanup is not always in `finally`
- request-local caches must never leak across requests
- global derived binding clients can become stale across isolate reuse and binding-only deploy changes
- Workers AI adds latency, cost, and remote-test constraints that need explicit docs and guardrails
- binary payload support increases buffering and memory pressure risk for large bodies

## Security And Reliability Notes

- `binding_rpc` must use an explicit allowlist and validate argument shapes
- D1 wrappers should steer users toward prepared statements and `bind()` patterns
- model output from Workers AI must be treated as untrusted input
- Queue-based offloading should be the recommended path for long-running or retry-heavy background AI workflows
- raw binding access is an escape hatch and should be documented as lower-level and less stable than typed wrappers

## Testing Plan

### OCaml unit tests

- async handler lifting and composition
- router behavior parity under async execution
- `recover` catches sync and async failure paths
- `Response.Body` encoding behavior

### JS unit tests

- ALS request propagation
- Map fallback lookup and cleanup
- binding RPC allowlist and validation
- per-request cache isolation

### Integration tests

- simulated binding coverage for KV, R2, D1, Queues, and Durable Objects
- service binding coverage where practical
- explicit strategy for remote-only AI validation vs mocked CI validation

### Stress tests

- concurrent requests under ALS and Map strategies
- cleanup verification after failures
- large binary payload sanity checks

## Success Criteria

This plan is done only when:

- async handlers are the internal truth across Thunder's request lifecycle
- sync Thunder apps still run unchanged through compatibility lifting
- request-local raw `env` and `ctx` access exists without abandoning the JSON ABI
- typed wrappers exist for KV, R2, DO, Queues, D1, service bindings, and Workers AI
- binary response bodies are supported through `body_base64`
- standalone examples prove the common Cloudflare workflows
- Zephyr interop is demonstrated without coupling Thunder to Zephyr's storage internals
- docs and release notes describe the new runtime model clearly
