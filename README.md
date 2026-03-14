# Thunder

Thunder is an OCaml-first edge framework for Cloudflare Workers.

Note: Thunder is still in active development and may break without warning until it reaches its first major version.

Thunder gives you:

- a typed request/response API
- a router and middleware model
- a Dune-driven build flow
- preview upload and production deploy through Wrangler

If you want to build an app with Thunder, start with `KICKSTART.md`.

## Quick Start

```bash
thunder doctor
thunder new my-app
cd my-app
npm install
dune build
```

`thunder doctor` reports how the Thunder binary resolves its framework home and checks the local tools Thunder expects.

## What You Build

A Thunder app is a generated project with these main places to edit:

- `app/routes.ml`
- `app/middleware.ml`
- `worker/entry.ml`

In most apps:

- `app/routes.ml` defines routes and handlers
- `app/middleware.ml` applies app-wide middleware
- `worker/entry.ml` stays small and only wires the app into the Worker export

## Prerequisites

- OCaml + opam + dune
- Node.js + npm
- local Wrangler install via `npm install`
- `wasm_of_ocaml-compiler`
- CMake + Ninja
- Linux/CI may also require `binaryen` for `wasm-merge`

Optional:

- `odoc` for local docs builds

Example setup:

```bash
opam install dune wasm_of_ocaml-compiler odoc
npm install
```

## Generated App Workflow

Create an app:

```bash
thunder new my-app
cd my-app
npm install
```

Build it:

```bash
dune build
```

That build does three things:

1. compiles the app to Worker runtime artifacts
2. stages a deploy-ready Worker tree
3. uploads a preview when credentials are present and the artifact hash changed

Useful commands inside a generated app:

```bash
# run the normal build flow
dune build

# build runtime artifacts only
dune build @worker-build

# run tests
dune runtest

# explicit production deploy
CONFIRM_PROD_DEPLOY=1 dune build @deploy-prod
```

Preview metadata is written to `.thunder/preview.json`.

## Cloudflare Setup

Thunder uses Wrangler for preview uploads and production deploys.

Set a Cloudflare API token:

```bash
export CLOUDFLARE_API_TOKEN="<your-token>"
```

Set your Cloudflare account id in `wrangler.toml`:

```toml
account_id = "<your-cloudflare-account-id>"
compatibility_flags = ["nodejs_compat"]
```

Find your account id with:

```bash
npx wrangler whoami
```

If `CLOUDFLARE_API_TOKEN` is not set, `dune build` still succeeds and preview upload is skipped.

## Build Outputs

The main generated outputs are:

- `_build/default/dist/worker/thunder_runtime.mjs`
- `_build/default/dist/worker/thunder_runtime.assets/*.wasm`
- `_build/default/dist/worker/manifest.json`
- `_build/default/deploy/wrangler.toml`
- `_build/default/deploy/worker_runtime/index.mjs`
- `_build/default/deploy/worker_runtime/app_abi.mjs`
- `_build/default/deploy/worker_runtime/compiled_runtime_backend.mjs`
- `.thunder/preview.json`

## Runtime Model

Thunder compiles your app to a Wasm-backed runtime bundle and deploys it behind a thin Cloudflare Worker host.

At runtime:

- the Worker host receives `fetch(request, env, ctx)`
- Thunder encodes the request through a JSON ABI
- the compiled OCaml app runs the router, middleware, and handlers
- Thunder encodes the response back to the Worker host
- the Worker host returns the final `Response`

For the detailed architecture walkthrough, see `docs/architecture.md`.

## API At A Glance

Top-level module: `Thunder`

Submodules:

- `Thunder.Method`
- `Thunder.Status`
- `Thunder.Headers`
- `Thunder.Cookie`
- `Thunder.Query`
- `Thunder.Context`
- `Thunder.Request`
- `Thunder.Response`
- `Thunder.Router`
- `Thunder.Worker`

Convenience exports:

- routing: `Thunder.get`, `Thunder.post`, `Thunder.put`, `Thunder.patch`, `Thunder.delete`, `Thunder.router`
- responses: `Thunder.text`, `Thunder.html`, `Thunder.json`, `Thunder.redirect`
- middleware: `Thunder.logger`, `Thunder.recover`

## Working On Thunder Itself

This repository is the Thunder framework source tree.

Useful commands at repo root:

```bash
npm install
dune build
dune runtest
bash scripts/check_mli.sh
bash scripts/verify_generated_app_fixture.sh
```

The app deployed from this repository lives in `packages/thunder_worker/wasm_entry.ml`.

The `examples/` directory contains reference examples for learning the API; those examples are not the app this repository deploys by default.

## Examples

- `examples/hello_site`
- `examples/json_api`
- `examples/cookies`
- `examples/params`
- `examples/middleware`
- `examples/env_binding`

## Troubleshooting

- `Program odoc not found`: install `odoc` with `opam install odoc`
- preview upload skipped: export `CLOUDFLARE_API_TOKEN`
- account/auth errors: verify `account_id` in `wrangler.toml`
- Wrangler missing: run `npm install`
- worker artifacts missing: run `dune build @worker-build`
- deploy tree missing: run `dune build` and inspect `_build/default/deploy/`

## Current Limitations

- buffered body only
- no streaming response API
- no multipart parser
- no WebSockets
- Cloudflare Workers target only

## Additional Docs

- `KICKSTART.md`
- `docs/architecture.md`
- `docs/supported_features.md`
- `docs/deployment.md`
- `docs/runtime_parity_matrix.md`
- `docs/examples.md`
