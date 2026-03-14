Current active phase: complete - runtime architecture settled for current release scope

# Thunder MVP Backlog

## Execution model

Build Thunder in ordered phases. Complete each phase before moving on unless a later task is blocked only by test scaffolding or docs. Do not skip interface work. For every public module, create the `.mli` first or in the same change as the `.ml`.

Each task should produce:

- code
    
- tests
    
- docs or comments when applicable
    

Each phase ends with a checkpoint commit and a short status note in `PLAN.md`.

---

# Global rules

## Rules the agent must follow

1. Do not widen scope beyond the MVP spec.
    
2. Do not add streaming, multipart, or WebSockets in MVP.
    
3. Do not implement a native server backend.
    
4. Keep the Worker JS runtime minimal.
    
5. Put deploy logic in `thunder_cli`, not in shell scripts unless trivial.
    
6. Every public module must have an `.mli`.
    
7. Prefer opaque types for core HTTP structures.
    
8. Every public function must be covered by either a test or an example.
    
9. Unsupported features must fail clearly.
    
10. Keep the public API small and stable.
    

## Definition of done for any task

A task is done only when:

- code compiles
    
- tests relevant to that task pass
    
- interfaces are updated
    
- the module has at least minimal doc comments
    
- any new user-facing behavior is reflected in examples or docs

## Phase status audit (current)

- Phase 0 — Repository foundation: **complete**
- Phase 1 — Core non-HTTP primitives: **complete**
- Phase 2 — HTTP primitives: **complete**
- Phase 3 — Handler and middleware model: **complete**
- Phase 4 — Router: **complete**
- Phase 5 — Top-level `Thunder` public API: **complete**
- Phase 6 — Worker runtime adapter: **complete**
- Phase 7 — Build artifacts and Wasm build path: **complete**
- Phase 8 — CLI and preview publishing: **complete**
- Phase 9 — Example apps: **complete**
- Phase 10 — Documentation hardening: **complete**
- Phase 11 — CI and quality gates: **complete**
- Phase 12 — MVP stabilization and release prep: **complete**
- Phase 13 — Runtime wiring and preview metadata hardening: **complete**
- Phase 14 — Thunder-owned runtime ABI v2: **complete**
- Phase 15 — Host/shim split: **complete**
- Phase 16 — Manifest-driven artifacts: **complete**
- Phase 17 — Explicit runtime backend: **complete**
- Phase 18 — Canary rollout and rollback controls: **complete**
- Phase 19 — Legacy runtime removal: **complete**

Earliest incomplete phase and active target: **none** (all planned runtime phases complete).
    

---

# Phase 0 — Repository foundation

## Goal

Create the repo skeleton, toolchain wiring, and baseline policies so later work does not drift.

## Tasks

### 0.1 Create repository structure

Create:

- `dune-project`
    
- `package.json`
    
- `wrangler.toml`
    
- `worker_runtime/`
    
- `packages/thunder_core/`
    
- `packages/thunder_http/`
    
- `packages/thunder_router/`
    
- `packages/thunder_worker/`
    
- `packages/thunder_cli/`
    
- `examples/`
    
- `docs/`
    

Acceptance:

- repo structure exists
    
- placeholder dune files exist where needed
    

### 0.2 Initialize Dune project

Create valid `dune-project` and package-local `dune` files.

Acceptance:

- `dune build` runs even if the repo mostly contains placeholders
    

### 0.3 Add Node/Wrangler project setup

Create `package.json` with local Wrangler dependency and useful scripts.

Acceptance:

- package install succeeds
    
- local Wrangler binary is available through package manager scripts
    

### 0.4 Add baseline Wrangler config

Create `wrangler.toml` for preview-oriented development.

Acceptance:

- config exists and is syntactically valid
    
- main entry points to `worker_runtime/index.mjs`
    

### 0.5 Add top-level docs

Create:

- `README.md`
    
- `docs/architecture.md`
    
- `docs/supported_features.md`
    
- `docs/deployment.md`
    
- `docs/api_style.md`
    
- `docs/mli_guidelines.md`
    

Acceptance:

- each file contains at least a stub with headings
    

### 0.6 Add CI skeleton

Set up CI workflow for:

- OCaml build
    
- tests
    
- docs generation
    
- Node install
    

Acceptance:

- CI config exists
    
- local lint/build commands are documented
    

### 0.7 Add policy script for `.mli` enforcement

Create a simple script that fails if a public module has `.ml` but no `.mli`.

Acceptance:

- script runs locally
    
- CI can call it later
    

### 0.8 Add checkpoint note

Write a short note into `PLAN.md` describing completed foundation work and remaining phases.

---

# Phase 1 — Core non-HTTP primitives

## Goal

Build the tiny shared substrate used by the rest of the system.

## Tasks

### 1.1 Create `thunder_core` package

Add package dune file and expose a minimal namespace.

Acceptance:

- package builds
    

### 1.2 Implement `Context` interface

Create:

- `context.mli`
    
- `context.ml`
    

Need:

- typed keys
    
- request-local typed storage mechanism
    
- immutable add/get semantics
    

Acceptance:

- opaque types
    
- tests cover storing and retrieving multiple typed values
    

### 1.3 Implement small internal utility module

Create a private utility module for string helpers / list helpers only if actually needed.

Acceptance:

- no unnecessary abstraction
    
- utilities remain internal
    

### 1.4 Add tests for `Context`

Test:

- key uniqueness
    
- retrieval by key
    
- absent key behavior
    
- preservation across copies
    

### 1.5 Document `Context`

Add module comments explaining invariants and intended use.

---

# Phase 2 — HTTP primitives

## Goal

Build transport-agnostic HTTP types with stable interfaces.

## Tasks

### 2.1 Implement `Method`

Create:

- `method.mli`
    
- `method.ml`
    

Need:

- standard HTTP methods used in MVP
    
- parser from string
    
- serializer to string
    
- equality support
    

Acceptance:

- parse tests
    
- normalization tests
    

### 2.2 Implement `Status`

Create:

- `status.mli`
    
- `status.ml`
    

Need:

- core statuses for MVP
    
- code accessor
    
- reason phrase accessor
    
- common values like `ok`, `not_found`, `internal_server_error`
    

Acceptance:

- tests verify codes and phrases
    

### 2.3 Implement `Header`

Create:

- `header.mli`
    
- `header.ml`
    

Need:

- normalized header name behavior
    
- pair representation if desired
    

Acceptance:

- case-insensitive lookup semantics are documented
    

### 2.4 Implement `Headers`

Create:

- `headers.mli`
    
- `headers.ml`
    

Need:

- opaque collection
    
- lookup single
    
- lookup all
    
- set
    
- add
    
- remove if useful
    
- preserve repeated headers
    

Acceptance:

- repeated header tests
    
- case-insensitive lookup tests
    
- `Set-Cookie` preservation tests
    

### 2.5 Implement `Query`

Create:

- `query.mli`
    
- `query.ml`
    

Need:

- parse query string
    
- get one
    
- get all
    
- preserve repeated keys
    

Acceptance:

- tests cover empty, repeated, encoded keys/values
    

### 2.6 Implement `Cookie`

Create:

- `cookie.mli`
    
- `cookie.ml`
    

Need:

- request cookie parsing
    
- response cookie serialization type, e.g. `Cookie.set`
    
- support common attributes for set-cookie
    

Acceptance:

- tests for parse
    
- tests for serialization
    
- repeated cookie header compatibility
    

### 2.7 Implement `Request`

Create:

- `request.mli`
    
- `request.ml`
    

Need:

- opaque request type
    
- method
    
- url
    
- path
    
- headers
    
- query
    
- cookie
    
- param
    
- body access
    
- context access
    

Use buffered body only for MVP.

Acceptance:

- tests cover all getters
    
- params can be absent before routing
    
- body string/bytes consistent
    

### 2.8 Implement `Response`

Create:

- `response.mli`
    
- `response.ml`
    

Need:

- opaque response type
    
- constructors: `empty`, `text`, `html`, `json`, `redirect`
    
- modifiers: status, header, add_header, cookie
    
- accessors for status and headers
    
- body representation hidden
    

Acceptance:

- constructors set expected status/content-type
    
- repeated headers supported
    
- redirect sets `Location`
    

### 2.9 Create `thunder_http` umbrella interface

Create:

- `thunder_http.mli`
    
- `thunder_http.ml`
    

Re-export:

- `Method`
    
- `Status`
    
- `Headers`
    
- `Cookie`
    
- `Query`
    
- `Request`
    
- `Response`
    

Acceptance:

- package users can depend on one public module if desired
    

### 2.10 Add full unit test suite for HTTP primitives

Tests should cover:

- methods
    
- statuses
    
- headers
    
- query parsing
    
- cookies
    
- request construction
    
- response modification
    

### 2.11 Add docs for HTTP modules

Document invariants and edge-specific notes where relevant.

---

# Phase 3 — Handler and middleware model

## Goal

Define the execution model that routers and adapters use.

## Tasks

### 3.1 Define `handler` abstraction

Create:

- `handler.mli`
    
- `handler.ml`
    

Need:

- abstract handler type
    
- constructor from `(Request.t -> Response.t)`
    
- invocation function, likely internal/public as needed
    

Acceptance:

- handler remains opaque
    
- test simple invocation
    

### 3.2 Define middleware abstraction

Create:

- `middleware.mli`
    
- `middleware.ml`
    

Need:

- middleware type alias or opaque type
    
- compose function
    
- apply_many function if useful
    

Acceptance:

- composition order is explicit and tested
    

### 3.3 Implement `recover` middleware

Need:

- catch exceptions
    
- map to internal server error response
    
- safe default message
    

Acceptance:

- thrown exception yields 500 response
    
- behavior documented
    

### 3.4 Implement `logger` middleware stub

Need:

- minimal request logging abstraction
    
- for MVP can be simple/no-op-friendly
    

Acceptance:

- middleware composes cleanly
    
- tests verify it does not alter normal response behavior
    

### 3.5 Implement simple response-header middleware

Need:

- helper middleware to inject a header
    

Acceptance:

- tests verify header injection
    

### 3.6 Add tests for handler and middleware

Test:

- single middleware
    
- composition order
    
- recover catches exceptions
    
- logger does not interfere
    

### 3.7 Add docs for execution model

Document handler lifecycle and middleware ordering.

---

# Phase 4 — Router

## Goal

Create a pure router with path params and predictable dispatch.

## Tasks

### 4.1 Create `thunder_router` package

Set up package and namespace.

Acceptance:

- package builds
    

### 4.2 Define `route` interface

Create:

- `router.mli`
    
- `router.ml`
    

Need:

- route type
    
- router type
    
- route constructors for GET/POST/PUT/PATCH/DELETE
    
- `make`
    
- `dispatch`
    

Acceptance:

- interfaces are stable and opaque where appropriate
    

### 4.3 Implement path pattern parser

Support:

- `/`
    
- static segments
    
- named params like `:id`
    

Do not implement splats in MVP.

Acceptance:

- parser tests cover valid and invalid patterns
    

### 4.4 Implement route matcher

Need:

- method match
    
- path segment match
    
- param extraction
    

Acceptance:

- path params extracted correctly
    

### 4.5 Implement route precedence rules

Define and test precedence:

- exact route over param route where applicable
    
- first-match behavior if chosen
    
- document the chosen rule
    

Acceptance:

- precedence behavior is deterministic and tested
    

### 4.6 Integrate matched params into `Request`

Need:

- dispatch returns handler and/or enriched request
    
- selected design must preserve request immutability
    

Acceptance:

- handlers can read params via `Request.param`
    

### 4.7 Implement high-level `router` handler constructor

Need:

- convert route list into a handler
    
- return 404 when no route matches
    
- optionally 405 later only if cheap and clear
    

Acceptance:

- route miss returns 404
    

### 4.8 Add router tests

Test:

- root route
    
- static routes
    
- param routes
    
- method mismatch
    
- not found
    
- precedence
    

### 4.9 Add router docs

Document supported pattern syntax and limitations.

---

# Phase 5 — Top-level `Thunder` public API

## Goal

Provide the stable public entrypoint developers will use.

## Tasks

### 5.1 Create `thunder.mli`

Define:

- top-level submodules
    
- `handler`
    
- `middleware`
    
- convenience functions like `get`, `post`, `router`, `text`, `html`, `json`, `redirect`
    
- `logger`
    
- `recover`
    

Acceptance:

- the top-level API is concise and aligned with the spec
    

### 5.2 Implement `thunder.ml`

Re-export and delegate to lower modules.

Acceptance:

- no new business logic beyond glue unless necessary
    

### 5.3 Add public API smoke tests

Write tests using only `Thunder` module surface.

Acceptance:

- sample apps can compile against top-level API only
    

### 5.4 Add top-level API docs

Include short examples for:

- basic route
    
- middleware composition
    
- JSON response
    

---

# Phase 6 — Worker runtime adapter

## Goal

Bridge portable Thunder handlers to Cloudflare Worker execution.

## Tasks

### 6.1 Create `thunder_worker` package

Set up dune and namespace.

Acceptance:

- package builds
    

### 6.2 Define Worker-facing interfaces

Create:

- `worker.mli`
    
- `worker.ml`
    
- `runtime.mli`
    
- `runtime.ml`
    

Need:

- `env` access from request
    
- `ctx` access from request
    
- runtime entrypoint abstractions
    

Acceptance:

- interfaces remain small
    

### 6.3 Design minimal ABI

Document in `docs/architecture.md` or separate ABI section:

- request fields passed into OCaml
    
- response fields returned
    

Acceptance:

- design is simple and buffered-only
    

### 6.4 Implement request decoding helper

Need:

- method string to `Method.t`
    
- url/path/query parsing
    
- header conversion
    
- body bytes/string
    
- attach env/ctx into request context
    

Acceptance:

- integration-friendly constructor exists
    

### 6.5 Implement response encoding helper

Need:

- status code extraction
    
- headers list
    
- body extraction
    
- preserve repeated `Set-Cookie`
    

Acceptance:

- test fixtures validate encoded output
    

### 6.6 Implement runtime entrypoint in OCaml

Need:

- a stable function that accepts decoded request parts
    
- invokes handler
    
- returns encoded response parts
    

Acceptance:

- pure adapter path can be tested without real Worker deployment
    

### 6.7 Implement JS host in `worker_runtime/index.mjs`

Need:

- instantiate Wasm
    
- cache module instance
    
- receive Fetch API request
    
- fully buffer request body
    
- pass values into Wasm boundary
    
- create final `Response`
    

Acceptance:

- host remains minimal
    
- placeholder imports are documented
    

### 6.8 Create a Worker example wiring path

Need:

- one example app deployable through the adapter
    

Acceptance:

- hello-world path works locally
    

### 6.9 Add integration tests for worker adapter

Test:

- GET request
    
- JSON response
    
- 404
    
- redirect
    
- multiple cookies
    
- env attachment presence if testable
    

### 6.10 Add runtime docs

Document:

- request flow
    
- Wasm boundary
    
- current limitations
    

---

# Phase 7 — Build artifacts and Wasm build path

## Goal

Make the Wasm and runtime artifacts reproducible and visible to Dune/CLI.

## Tasks

### 7.1 Decide artifact locations

Pick stable paths for:

- compiled Wasm
    
- generated JS host artifacts if copied/generated
    
- preview metadata file
    

Acceptance:

- paths documented in `docs/deployment.md`
    

### 7.2 Add Dune targets for Worker build

Create `@worker-build` alias and required rules/deps.

Acceptance:

- running the alias builds all deployable artifacts
    

### 7.3 Wire Wasm build into Dune

Implement the actual Wasm target path based on chosen OCaml/Wasm toolchain.

Acceptance:

- Wasm artifact is emitted consistently
    
- example app builds to artifact location
    

### 7.4 Add artifact existence validation

Need:

- build or CLI checks that expected files exist before publish/deploy
    

Acceptance:

- failures are explicit and readable
    

### 7.5 Add docs for build outputs

Document where artifacts are and which pieces are inputs to preview publishing.

---

# Phase 8 — CLI and preview publishing

## Goal

Make normal `dune build` automatically publish previews when outputs change.

## Tasks

### 8.1 Create `thunder_cli` package

Set up:

- `main.mli` only if needed internally
    
- `main.ml`
    
- `artifact_hash.mli/ml`
    
- `wrangler.mli/ml`
    
- `preview_publish.mli/ml`
    
- `deploy_prod.mli/ml`
    

Acceptance:

- CLI executable builds
    

### 8.2 Implement artifact hashing

Need:

- hash computed from deployable artifacts
    
- stable ordering
    
- ability to read/write last hash metadata
    

Acceptance:

- tests verify unchanged content yields same hash
    

### 8.3 Implement preview metadata storage

Need:

- store last artifact hash
    
- optionally store last preview info/version id/url
    

Acceptance:

- metadata file format is documented
    
- reads missing file gracefully
    

### 8.4 Implement Wrangler wrapper module

Need:

- locate/call local Wrangler
    
- abstract command execution
    
- capture exit status and output
    

Acceptance:

- wrapper tests for command construction
    
- shelling behavior isolated
    

### 8.5 Implement preview publish command

Behavior:

- verify artifacts
    
- compute current hash
    
- compare to previous hash
    
- skip if unchanged unless forced
    
- run preview publish when changed
    
- persist metadata
    
- print readable status
    

Acceptance:

- command supports skip and publish paths
    

### 8.6 Implement force-preview mode

Need:

- env var or flag to force publish even if unchanged
    

Acceptance:

- documented and tested
    

### 8.7 Implement production deploy command

Behavior:

- explicit only
    
- require `CONFIRM_PROD_DEPLOY=1`
    
- verify artifacts
    
- invoke Wrangler production deploy
    

Acceptance:

- safe failure when confirmation missing
    

### 8.8 Add Dune aliases

Need:

- `@preview-publish`
    
- `@deploy-prod`
    
- `@@default` includes `@worker-build` and preview publish behavior
    

Acceptance:

- `dune build` triggers preview logic
    
- `dune build @deploy-prod` remains explicit
    

### 8.9 Add lock around preview publish

Prevent concurrent publish races during watch/build churn.

Acceptance:

- locking configured in Dune rule/alias path as applicable
    

### 8.10 Add CLI tests

Test:

- skip unchanged
    
- publish changed
    
- force publish
    
- missing artifact failure
    
- production confirmation guard
    

### 8.11 Add deploy docs

Document:

- normal build flow
    
- force preview flow
    
- production deploy flow
    
- local prerequisites
    

---

# Phase 9 — Example apps

## Goal

Provide concrete examples that also act as smoke tests.

## Tasks

### 9.1 `examples/hello_site`

Build simple HTML page using top-level API.

Acceptance:

- deployable and testable
    

### 9.2 `examples/json_api`

Build:

- `GET /health`
    
- `POST /echo`
    

Acceptance:

- request body path works
    

### 9.3 `examples/cookies`

Build:

- read request cookie
    
- set response cookies
    

Acceptance:

- multiple cookies supported
    

### 9.4 `examples/params`

Build:

- path param route
    
- query param usage
    

Acceptance:

- output proves params were parsed
    

### 9.5 `examples/middleware`

Build:

- logger
    
- recover
    
- header injection middleware
    

Acceptance:

- one route intentionally demonstrates recover behavior
    

### 9.6 `examples/env_binding`

Build:

- response influenced by Worker env binding
    

Acceptance:

- env access path works through request
    

### 9.7 Add example tests

Each example should have at least one smoke test.

### 9.8 Add example docs

Document how to build/run each example.

---

# Phase 10 — Documentation hardening

## Goal

Make the MVP understandable and maintainable after compaction cycles.

## Tasks

### 10.1 Expand `README.md`

Include:

- what Thunder is
    
- what it is not
    
- quick start
    
- preview deploy model
    
- examples list
    

### 10.2 Finalize `docs/supported_features.md`

Create clear supported/deferred matrix.

### 10.3 Finalize `docs/architecture.md`

Document:

- package layout
    
- request lifecycle
    
- runtime boundary
    
- why no streaming in MVP
    

### 10.4 Finalize `docs/deployment.md`

Document:

- dune alias model
    
- preview publish on build
    
- production deploy
    
- metadata files and artifact paths
    

### 10.5 Finalize `docs/api_style.md`

Document:

- opaque types
    
- naming rules
    
- top-level API philosophy
    

### 10.6 Finalize `docs/mli_guidelines.md`

Document:

- every public module needs `.mli`
    
- when to hide constructors
    
- required comment structure
    

### 10.7 Ensure odoc-compatible comments exist

Public modules should have module doc comments and key value docs.

Acceptance:

- doc generation succeeds cleanly
    

---

# Phase 11 — CI and quality gates

## Goal

Prevent regression and drift.

## Tasks

### 11.1 Wire `.mli` enforcement into CI

Fail if public module missing interface.

### 11.2 Wire tests into CI

Run:

- unit tests
    
- integration tests
    
- example smoke tests
    

### 11.3 Wire docs generation into CI

Ensure odoc build works.

### 11.4 Add formatting/lint step if chosen

Keep it modest; do not add a heavy tool burden unless helpful.

### 11.5 Add artifact/build smoke step

Ensure Worker artifacts are generated in CI.

### 11.6 Add CLI dry-run or test-mode step

So deploy logic can be validated without real deploy in CI if needed.

---

# Phase 12 — MVP stabilization and release prep

## Goal

Turn the built system into a coherent MVP release candidate.

## Tasks

### 12.1 Audit public API against spec

Check:

- names
    
- module layout
    
- signatures
    
- top-level convenience functions
    

### 12.2 Audit deferred features are clearly deferred

Make sure unsupported items:

- are not half-exposed
    
- fail clearly
    
- are documented
    

### 12.3 Audit examples against docs

Ensure README/examples/docs all align.

### 12.4 Add release checklist

Create `docs/release_checklist.md` including:

- build
    
- tests
    
- docs
    
- example verification
    
- preview flow verification
    
- production deploy sanity
    

### 12.5 Write MVP limitations section

Be explicit about:

- buffered body only
    
- no streaming
    
- no multipart
    
- no WebSockets
    
- Cloudflare Workers target only
    

### 12.6 Final checkpoint note

Update `PLAN.md` with completed MVP summary and next-post-MVP ideas.

---

# Suggested file-by-file creation order

This order is optimized for compaction resilience.

## Group A — Foundation

1. `dune-project`
    
2. `package.json`
    
3. `wrangler.toml`
    
4. top-level `README.md`
    
5. `docs/architecture.md`
    
6. `docs/deployment.md`
    
7. package `dune` files
    
8. `.mli` enforcement script
    

## Group B — Core primitives

9. `packages/thunder_core/context.mli`
    
10. `packages/thunder_core/context.ml`
    

## Group C — HTTP interfaces first

11. `packages/thunder_http/method.mli`
    
12. `packages/thunder_http/status.mli`
    
13. `packages/thunder_http/header.mli`
    
14. `packages/thunder_http/headers.mli`
    
15. `packages/thunder_http/query.mli`
    
16. `packages/thunder_http/cookie.mli`
    
17. `packages/thunder_http/request.mli`
    
18. `packages/thunder_http/response.mli`
    
19. `packages/thunder_http/thunder_http.mli`
    

## Group D — HTTP implementations

20. `method.ml`
    
21. `status.ml`
    
22. `header.ml`
    
23. `headers.ml`
    
24. `query.ml`
    
25. `cookie.ml`
    
26. `request.ml`
    
27. `response.ml`
    
28. `thunder_http.ml`
    

## Group E — Execution model

29. `packages/thunder_http/handler.mli`
    
30. `packages/thunder_http/middleware.mli`
    
31. `handler.ml`
    
32. `middleware.ml`
    

## Group F — Router

33. `packages/thunder_router/router.mli`
    
34. `packages/thunder_router/router.ml`
    

## Group G — Public API

35. `packages/thunder_http/thunder.mli`
    
36. `packages/thunder_http/thunder.ml`
    

## Group H — Worker adapter

37. `packages/thunder_worker/worker.mli`
    
38. `packages/thunder_worker/runtime.mli`
    
39. `packages/thunder_worker/worker.ml`
    
40. `packages/thunder_worker/runtime.ml`
    
41. `worker_runtime/index.mjs`
    

## Group I — CLI

42. `packages/thunder_cli/artifact_hash.mli`
    
43. `packages/thunder_cli/wrangler.mli`
    
44. `packages/thunder_cli/preview_publish.mli`
    
45. `packages/thunder_cli/deploy_prod.mli`
    
46. `packages/thunder_cli/artifact_hash.ml`
    
47. `packages/thunder_cli/wrangler.ml`
    
48. `packages/thunder_cli/preview_publish.ml`
    
49. `packages/thunder_cli/deploy_prod.ml`
    
50. `packages/thunder_cli/main.ml`
    

## Group J — Examples

51. `examples/hello_site/main.ml`
    
52. `examples/json_api/main.ml`
    
53. `examples/cookies/main.ml`
    
54. `examples/params/main.ml`
    
55. `examples/middleware/main.ml`
    
56. `examples/env_binding/main.ml`
    

## Group K — Tests and docs hardening

57. add all missing tests
    
58. finalize docs
    
59. wire CI fully
    
60. release checklist
    

---

# Compaction-cycle guidance for the agent

When context gets tight, preserve these invariants in summaries:

1. Thunder is not a Dream port.
    
2. MVP is Cloudflare Workers only.
    
3. Every public module must have `.mli`.
    
4. No streaming/multipart/WebSockets in MVP.
    
5. `dune build` must auto-publish preview when artifacts changed.
    
6. Production deploy must remain explicit.
     
7. Core architecture order is:
    
    - core/context
        
    - HTTP primitives
        
    - handler/middleware
        
    - router
        
    - top-level API
        
    - worker adapter
        
    - CLI/deploy
         
    - examples/tests/docs

8. Current active phase is Phase 14 until `PLAN.md` explicitly advances it.

9. The first production-ready Thunder-owned ABI rollout remains JSON-based.

10. Do not reintroduce compiler side effects as the public runtime contract.

11. Preview and production deploys must use the same staged deploy shape.

12. Compaction must not change the active phase or ABI direction without updating `PLAN.md`.
        

When resuming after compaction, the agent should first:

- inspect which phases are complete
    
- inspect whether `.mli` files exist for all public modules already created
    
- run tests/build
    
- continue from the next unfinished phase only
    

---

# Minimal phase checkpoints for `PLAN.md`

Use this format after each phase:

```md
## Checkpoint: Phase N complete
Completed:
- ...
- ...
- ...

Verified:
- dune build
- relevant tests
- docs/interfaces updated

Next:
- ...
```

---

# Final instruction block for the agent

Build Thunder as an edge-native OCaml framework for Cloudflare Workers. Follow the phased backlog in order. Do not skip `.mli` files. Keep the MVP narrow and stable. Prefer completing a smaller fully-tested slice over partially implementing deferred features. Ensure that `dune build` triggers preview publication when deployable artifacts changed, while production deployment remains explicit. Use the examples and tests as stability anchors throughout the build.

---

# Phase 13 — Runtime wiring and preview metadata hardening

## Goal

Complete the production-grade path for the two remaining MVP hardening items:

1. real Wasm runtime invocation from `worker_runtime/index.mjs`
2. richer preview metadata capture (version id + preview URL)

## Tasks

### 13.1 Define concrete ABI contract for JS <-> OCaml runtime

Specify the exact request payload shape and response payload shape used at the boundary.

Must include:

- method
- url
- headers (including repeated headers)
- body (buffered)
- env/ctx passthrough strategy
- response status
- response headers preserving repeated `set-cookie`
- response body

Acceptance:

- ABI documented in `docs/architecture.md`
- unsupported fields fail with clear errors

### 13.2 Implement real Wasm module loading in `worker_runtime/index.mjs`

Replace placeholder loading with:

- loading generated Wasm artifact from stable build location
- instance caching across requests
- explicit initialization error handling

Acceptance:

- runtime no longer uses placeholder-only path
- initialization failure returns explicit 500 with actionable message

### 13.3 Implement JS request encode + OCaml entrypoint invocation

Need:

- parse Fetch `Request` into ABI input
- buffer request body
- invoke Wasm-exported adapter entrypoint
- handle malformed return payloads safely

Acceptance:

- GET and POST JSON paths work end-to-end
- malformed runtime payload returns explicit 500

### 13.4 Implement JS response decode back to `Response`

Need:

- status extraction
- header reconstruction with repeated values preserved
- body reconstruction (buffered)

Acceptance:

- redirects, JSON responses, and multiple cookies are preserved end-to-end

### 13.5 Add runtime integration tests for wired host path

Test:

- GET route
- POST JSON echo
- 404
- redirect
- multiple set-cookie headers
- env visibility path

Acceptance:

- tests pass in local test harness
- docs include test execution notes

### 13.6 Extend preview metadata schema

Update metadata from hash-only to structured fields:

- `artifact_hash`
- `last_upload_at`
- `last_version_id`
- `last_preview_url`
- optional `raw_wrangler_output` (bounded/truncated if needed)

Acceptance:

- schema documented in `docs/deployment.md`
- metadata reads old hash-only format gracefully

### 13.7 Parse Wrangler preview output

Implement parsing logic in `thunder_cli` to extract version id and preview URL from `wrangler versions upload` output.

Acceptance:

- successful uploads persist parsed fields
- parse failure does not lose upload success state; stores fallback output snippet

### 13.8 Improve preview CLI output

Print consistent status lines for:

- skipped (unchanged)
- skipped (no token)
- uploaded with version id and preview URL
- upload failed with concise diagnostics

Acceptance:

- output is stable enough for CI logs and local debugging

### 13.9 Add tests for metadata and parser behavior

Test:

- old metadata migration
- successful parse of representative Wrangler outputs
- missing URL/version fallback path
- unchanged-hash skip behavior still intact

Acceptance:

- `dune runtest` covers parse + persistence paths

### 13.10 Final docs update and checkpoint

Update:

- `docs/architecture.md` runtime boundary section
- `docs/deployment.md` preview metadata and troubleshooting
- `README.md` preview behavior note with metadata fields

Acceptance:

- docs and implementation match
- phase checkpoint added with verified build/test status

## Checkpoint: Phase 13 complete
Completed:
- implemented concrete JS<->Wasm ABI request/response handling in `worker_runtime/index.mjs`
- added Wasm initialization/ABI validation errors with explicit runtime failure responses
- hardened preview metadata schema with backward-compatible hash migration and Wrangler output parsing
- expanded integration and CLI tests; added Node runtime tests for request encode/response decode validation

Verified:
- dune build
- dune runtest (including Node runtime tests)
- docs/interfaces updated

Next:
- exercise a real Wrangler preview upload in an environment with `CLOUDFLARE_API_TOKEN`
- continue post-MVP ergonomics and feature expansion planning

---

# Phase 14 — Thunder-owned runtime ABI v2

## Goal

Define and freeze a Thunder-owned, versioned, JSON-based runtime ABI so deployed edge apps target Thunder's contract rather than compiler side effects.

## Tasks

### 14.1 Mark active phase and freeze direction in planning/docs

Update planning and architecture docs so compaction cycles cannot silently drift the project back toward side-effect-driven runtime loading.

Need:

- explicit active phase marker at top of `PLAN.md`
- statement that first production rollout remains JSON-based
- statement that Thunder owns the runtime contract
- statement that preview/prod share one staged deploy shape

Acceptance:

- `PLAN.md` points to Phase 14 as active phase
- docs and plan clearly state ABI ownership and rollout direction

### 14.2 Define ABI v2 init/request/response schemas

Specify Thunder ABI v2 payloads for:

- `init(init_payload) -> init_result`
- `handle(request_payload) -> response_payload`

Must include:

- `abi_version`
- request method/url/repeated headers/body buffering strategy
- binary body via `body_base64`
- env bindings
- ctx capabilities
- response status/repeated headers/body
- initialization capabilities and diagnostics

Acceptance:

- ABI v2 schema is documented in `docs/architecture.md`
- versioning and compatibility notes are explicit

### 14.3 Close parity gap between documented ABI and deployed runtime

Rework deployed OCaml entrypoint so it uses the shared typed runtime bridge instead of bespoke JSON parsing that drops fidelity.

Need:

- route deployed runtime path through `packages/thunder_worker/runtime.ml`
- preserve headers, env, ctx, and buffered body fidelity
- preserve response header multiplicity and binary-safe response path

Acceptance:

- deployed runtime behavior matches documented ABI fields
- tests prove parity for headers/env/ctx/body/cookies/redirects/errors

### 14.4 Define ABI error taxonomy

Create stable categories for runtime failures:

- init failure
- request decode failure
- app execution failure
- response decode failure
- ABI mismatch / version mismatch

Acceptance:

- errors are documented with intended user-facing behavior
- runtime code has one clear error vocabulary to implement in later phases

### 14.5 Add ABI fixture and parity tests

Create tests for:

- request payload fixture shape
- response payload fixture shape
- repeated headers and `set-cookie`
- env binding preservation
- ctx capability preservation
- binary body encode/decode path
- invalid ABI/version mismatch behavior

Acceptance:

- `dune runtest` covers ABI parity cases
- Node runtime tests and OCaml runtime tests share the same fixture expectations

### 14.6 Add checkpoint note and first implementation slice

Record which part of ABI v2 is implemented first and what remains for Phase 15.

Acceptance:

- checkpoint note added after Phase 14 completion
- first concrete implementation slice for Phase 15 is listed

## Checkpoint: Phase 14 complete
Completed:
- marked Phase 14 as the active ABI migration target and added compaction guardrails so the project keeps the Thunder-owned JSON ABI direction
- documented ABI v2 direction, init/request/response schema targets, and runtime error taxonomy in `docs/architecture.md`
- reworked the deployed OCaml entrypoint to route through the shared typed runtime bridge so headers, env bindings, ctx features, and buffered body payloads are preserved
- added ABI fixture tests for request/response payload shape, ABI version rejection, repeated request headers, env/ctx parity, and initial `app_abi.mjs` init/handle behavior

Verified:
- `node --test worker_runtime/index_test.mjs`
- `opam exec -- dune runtest`
- `opam exec -- dune build`
- docs/interfaces updated

Next:
- continue Phase 15 by moving more runtime lifecycle responsibility into `worker_runtime/app_abi.mjs`
- reduce `worker_runtime/index.mjs` toward a thin Cloudflare-specific host that delegates all app runtime behavior to the shim

---

# Phase 15 — Host/shim split

## Goal

Make the Cloudflare Worker host minimal and route all runtime lifecycle behavior through a Thunder-owned shim with an explicit `init` + `handle` contract.

## Tasks

### 15.1 Introduce `worker_runtime/app_abi.mjs`

Create a Thunder-owned shim that becomes the only runtime module contract used by the Worker host.

Need:

- explicit `init`
- explicit `handle`
- internal cache for initialized app runtime
- no host-facing global registration assumptions

Acceptance:

- host imports only `app_abi.mjs`
- runtime lifecycle is centralized in the shim

### 15.2 Simplify `worker_runtime/index.mjs`

Reduce the Worker host to:

- Fetch API request decode
- one lazy `init` path
- one `handle` invocation path
- response decode and error handling

Acceptance:

- host no longer probes multiple adapter styles
- host remains small and Cloudflare-specific only

### 15.3 Add temporary compatibility backend inside the shim

During migration, allow the shim to wrap the legacy global-registration backend internally without exposing that behavior as the public contract.

Acceptance:

- legacy support exists only inside the shim
- host stays ABI-v2-oriented

### 15.4 Add host/shim tests

Test:

- one-time init caching
- request handling after init
- init failure behavior
- compatibility backend behavior during transition

Acceptance:

- Node host tests validate the new split
- behavior is documented for later legacy removal

## Checkpoint: Phase 15 complete
Completed:
- moved runtime lifecycle ownership into `worker_runtime/app_abi.mjs`, including init-state caching, compatibility backend handling, compiled-runtime adapter resolution, and Wasm fallback loading
- reduced `worker_runtime/index.mjs` to a thinner Cloudflare-specific host responsible primarily for request encode/response decode, init payload construction, and error mapping
- expanded Node runtime tests to cover shim init caching, internal adapter caching, ABI version rejection, and request/response handling through the new shim surface

Verified:
- `node --test worker_runtime/index_test.mjs`
- `opam exec -- dune runtest`
- `opam exec -- dune build`
- docs/interfaces updated

Next:
- continue Phase 16 by expanding the manifest schema and using it as the source of truth for deploy staging and artifact hashing
- reduce remaining hardcoded artifact assumptions in deploy tooling as manifest coverage expands

---

# Phase 16 — Manifest-driven artifacts

## Goal

Make deployment packaging explicit and deterministic through a Thunder-owned manifest rather than hardcoded filenames and compiler-output assumptions.

## Tasks

### 16.1 Define manifest schema

Create `dist/worker/manifest.json` with:

- ABI version
- app entry path
- asset paths
- artifact hash
- capabilities/features

Acceptance:

- manifest schema is documented
- manifest format is versioned independently from Thunder package version

### 16.2 Generate manifest during `@worker-build`

Need:

- Dune rule emits manifest alongside runtime artifacts
- manifest references every deploy-critical file

Acceptance:

- `dune build @worker-build` emits manifest consistently

### 16.3 Stage deploy tree from manifest

Update deployment staging to copy only manifest-declared files into `_build/default/deploy/`.

Acceptance:

- preview and prod both stage from manifest
- staging no longer depends on hardcoded file lists beyond manifest presence

### 16.4 Hash manifest + referenced files

Replace ad hoc artifact hashing with manifest-driven hashing.

Acceptance:

- unchanged manifest+artifact content yields stable hash
- preview skip behavior remains intact

### 16.5 Add packaging validation tests

Test:

- missing manifest failure
- missing referenced artifact failure
- stable staging shape
- preview metadata remains compatible

Acceptance:

- CLI and packaging tests cover manifest-driven deploy flow

## Checkpoint: Phase 16 complete
Completed:
- added `dist/worker/manifest.json` as a Thunder-owned artifact manifest describing the runtime entry, ABI shim, compiled runtime module, assets directory, and compatibility backend
- made deploy staging and validation manifest-driven in `thunder_cli`, so preview and production staging now resolve runtime files from the manifest instead of hardcoded paths
- switched artifact hashing to include the manifest plus all manifest-referenced artifacts and updated CLI tests to validate manifest parsing and staging behavior
- taught the runtime shim to use manifest-derived defaults for init metadata such as `app_id`, `asset_base_url`, and compatibility backend information

Verified:
- `node --test worker_runtime/index_test.mjs`
- `opam exec -- dune runtest`
- `opam exec -- dune build`
- docs/interfaces updated

Next:
- continue Phase 17 by replacing the legacy compatibility backend with a more explicit runtime export contract behind the shim
- reduce remaining bootstrap/global-registration assumptions from the steady-state runtime path

---

# Phase 17 — Explicit runtime backend

## Goal

Replace legacy side-effect registration with an explicit runtime backend behind the Thunder ABI shim.

## Tasks

### 17.1 Design explicit runtime export strategy

Determine how compiled app artifacts expose init/handle behavior without requiring host-visible globals.

Need:

- explicit runtime export or generated wrapper strategy
- compatibility notes for the OCaml/Wasm toolchain

Acceptance:

- strategy is documented and technically validated

### 17.2 Remove steady-state dependence on `document.currentScript`

Eliminate asset resolution hacks from the normal runtime path.

Acceptance:

- normal runtime path does not mutate `document.currentScript`
- Cloudflare global-scope restrictions are respected

### 17.3 Keep initialization request-time safe

Ensure runtime init happens only in Cloudflare-allowed contexts and is cached for reuse.

Acceptance:

- no forbidden global-scope async boot logic remains in steady-state path
- init and request handling are deterministic

### 17.4 Add explicit-backend tests

Test:

- init success
- ABI mismatch
- asset resolution failure
- app execution failure
- repeated request handling with cached init

Acceptance:

- explicit backend passes parity tests introduced in Phase 14

## Checkpoint: Phase 17 complete
Completed:
- introduced explicit runtime backend modules in `worker_runtime/legacy_runtime_backend.mjs` and `worker_runtime/wasm_runtime_backend.mjs`, and moved backend selection behind `worker_runtime/app_abi.mjs`
- removed remaining host-side global/bootstrap probing from `worker_runtime/index.mjs`, leaving the Worker host focused on Cloudflare request/response translation and error mapping only
- extended the manifest schema and deploy staging so explicit backend modules are staged and treated as part of the deployable runtime contract
- expanded Node runtime tests and CLI manifest tests to cover explicit backend selection, manifest fields, and shim-driven initialization behavior

Verified:
- `node --test worker_runtime/index_test.mjs`
- `opam exec -- dune runtest`
- `opam exec -- dune build`
- docs/interfaces updated

Next:
- continue Phase 18 by defining canary/rollback controls for switching between compatibility and explicit backend paths during rollout
- add response-parity and rollout validation guidance before removing the legacy compatibility backend entirely

---

# Phase 18 — Canary rollout and rollback controls

## Goal

Prove production readiness with a reversible migration path before fully removing legacy runtime behavior.

## Tasks

### 18.1 Add backend selection controls for rollout

Need:

- controlled switch between legacy compatibility backend and explicit ABI backend
- clear operator-facing documentation

Acceptance:

- preview canary can switch backends without code churn

Progress note:

- Worker env binding `THUNDER_RUNTIME_BACKEND` now feeds `requested_backend` into Thunder ABI init payload so canary and rollback backend selection can happen without code edits.

### 18.2 Build parity matrix across representative apps

Cover:

- GET
- POST JSON
- redirect
- repeated cookies
- env bindings
- 404/500 behavior
- binary body

Acceptance:

- response parity results are recorded and reproducible

Progress note:

- parity expectations are now tracked in `docs/runtime_parity_matrix.md` and mapped to existing integration/runtime tests plus manual preview-canary validation.

### 18.3 Add real preview smoke coverage

Need:

- CI or release-gated environment with Wrangler credentials
- smoke verification against built artifacts and staged deploy tree

Acceptance:

- preview canary path is exercised outside purely local tests

Progress note:

- added `scripts/preview_smoke.sh` and `.github/workflows/preview-smoke.yml` as the release-gated shape for credentialed preview canary execution.
- local environment check shows `CLOUDFLARE_API_TOKEN` is currently unavailable here, so the remaining Phase 18 gate is running the smoke path in a credentialed environment and recording results.

Validation result:

- credentialed preview smoke has now been validated against an existing Worker target for both `auto` and `legacy-global-registration`.
- rollback to `auto` was confirmed after explicit backend canary validation.

## Checkpoint: Phase 18 complete
Completed:
- added backend selection controls through `THUNDER_RUNTIME_BACKEND` and threaded them through the Thunder ABI init path
- added parity tracking in `docs/runtime_parity_matrix.md` plus release-gated smoke tooling in `scripts/preview_smoke.sh` and `.github/workflows/preview-smoke.yml`
- validated credentialed preview canaries for `auto` and `legacy-global-registration` against an existing Worker target
- confirmed rollback by returning backend selection to `auto`

Verified:
- `bash scripts/preview_smoke.sh auto` (with existing Worker override)
- `bash scripts/preview_smoke.sh legacy-global-registration` (with existing Worker override)
- `env -u CLOUDFLARE_API_TOKEN opam exec -- dune runtest`
- `opam exec -- dune build @worker-build`

Next:
- continue Phase 19 by removing the legacy compatibility runtime path from the supported contract
- simplify runtime/bootstrap code and docs around the remaining production path

### 18.4 Define rollback and deprecation notes

Acceptance:

- docs describe how to revert during rollout
- conditions for Phase 19 switch are explicit

Progress note:

- rollback guidance now centers on resetting `THUNDER_RUNTIME_BACKEND` to `auto`, and Phase 19 switch criteria are captured in `docs/runtime_parity_matrix.md`.

---

# Phase 19 — Legacy runtime removal

## Goal

Finalize Thunder around one production runtime contract and remove the temporary compatibility path.

## Tasks

### 19.1 Remove legacy bootstrap/probing code

Acceptance:

- no host-side adapter probing remains
- no legacy global-registration path remains as a supported contract

### 19.2 Simplify docs and troubleshooting

Need:

- one runtime model
- one deploy model
- one set of expected artifacts

Acceptance:

- docs/examples reflect only the ABI-v2 path

### 19.3 Final production hardening pass

Audit:

- runtime errors
- deploy packaging
- preview/prod parity
- public API/docs alignment

Acceptance:

- release checklist updated for the new runtime architecture
- legacy transition notes archived or removed as appropriate

## Checkpoint: Phase 19 complete
Completed:
- removed the legacy compatibility and alternate runtime backend paths from the supported contract, leaving a single compiled-runtime production path
- simplified manifest, deploy staging, smoke validation, and docs around one runtime model and one deploy model
- verified the current runtime path in credentialed Cloudflare preview using `scripts/preview_smoke.sh auto`

Verified:
- `env -u CLOUDFLARE_API_TOKEN opam exec -- dune runtest`
- `node --test worker_runtime/index_test.mjs`
- `opam exec -- dune build @worker-build`
- `THUNDER_SMOKE_WORKER_NAME="your-existing-worker" bash scripts/preview_smoke.sh auto`

Next:
- preserve the single-runtime architecture in future work
- treat any new runtime-path expansion as a new planned phase rather than reintroducing compatibility layers implicitly

## Checkpoint: Phase 7 complete
Completed:
- selected and documented stable worker artifact paths in deployment docs
- wired `@worker-build` alias to compile OCaml bytecode entrypoint through `wasm_of_ocaml`
- emitted compiled runtime module and companion Wasm asset directory under `dist/worker`
- validated artifact presence in preview/deploy flows

Verified:
- dune build
- dune build @worker-build
- docs/interfaces updated

Next:
- keep runtime ABI and artifact layout stable for deploy tooling

## Checkpoint: Phase 10 complete
Completed:
- expanded README quick-start and local validation commands
- finalized supported/deferred matrix and MVP limitations docs
- finalized architecture and deployment docs with runtime and metadata details
- ensured public modules include odoc-friendly module comments

Verified:
- dune build
- docs/interfaces updated

Next:
- maintain docs alongside API/runtime changes

## Checkpoint: Phase 11 complete
Completed:
- wired `.mli` policy script into CI workflow
- wired build/tests/doc generation into CI workflow
- added worker artifact smoke step in CI
- validated CLI behavior through automated tests in `dune runtest`

Verified:
- dune build
- dune runtest
- docs/interfaces updated

Next:
- maintain CI parity with local validation commands

## Checkpoint: Phase 12 complete
Completed:
- audited public API module names/signatures against MVP surface
- confirmed deferred features are explicitly documented and not half-exposed
- aligned examples and docs with current behavior
- maintained release checklist and MVP limitations sections

Verified:
- dune build
- dune runtest
- docs/interfaces updated

Next:
- begin post-MVP enhancements from backlog follow-ons

## Checkpoint: MVP baseline slice complete
Completed:
- repository scaffolding, package layout, dune aliases, docs stubs, and CI skeleton
- core/context, HTTP primitives, handler/middleware, router, top-level Thunder API
- worker adapter surface, CLI hashing + preview/prod orchestration, examples, and tests

Verified:
- mli enforcement script added and wired in CI
- `dune build` / `dune runtest` attempted for baseline validation
- docs/interfaces updated across public modules

Next:
- replace placeholder Wasm host wiring with real Wasm ABI bridge
- expand deployment metadata with parsed Wrangler preview URL/version id
- harden docs/odoc and add deeper CLI/integration coverage
