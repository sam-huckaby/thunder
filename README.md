# Thunder

Thunder is an OCaml-first edge framework for Cloudflare Workers.

It gives you a typed request/response API, router, middleware model, and a deploy workflow where normal `dune build` can publish preview versions when artifacts change.

## What Thunder is

- Edge-native request/response framework for Workers.
- OCaml-first API with `.mli` contracts.
- Dune-driven build and preview publish flow.

## What Thunder is not

- Not a Dream port.
- Not a native socket server.
- Not a streaming/multipart/WebSocket framework in MVP.

## Prerequisites

- OCaml + Dune
- Node.js + npm
- Wrangler local install via `npm install`
- Wasm toolchain used by this repo:
  - `opam install wasm_of_ocaml-compiler`
- Optional docs tool:
  - `opam install odoc`

## Quick Start

1. Install dependencies:

```bash
npm install
```

2. Build (includes worker artifact build + preview publish path):

```bash
dune build
```

3. Run tests:

```bash
dune runtest
```

4. Build docs (optional):

```bash
dune build @doc
```

## First App Walkthrough (`examples/hello_site`)

File: `examples/hello_site/main.ml`

The example defines one route:

- `GET /` returns HTML via `Thunder.html`.

Core flow in the example:

1. Build a route list with `Thunder.get`.
2. Wrap pure handler logic with `Thunder.handler`.
3. Compile routes into an app handler via `Thunder.router`.
4. Create a synthetic request with `Thunder.Request.make`.
5. Execute with `Thunder.Handler.run`.
6. Inspect the response body.

Important note: the `url` in examples (often `https://example.com/...`) is a placeholder used to simulate requests locally. In real Worker execution, Thunder gets the real URL from Cloudflare `fetch(request, env, ctx)` input.

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

## Cloudflare + Wrangler Setup

Thunder uses Wrangler for preview uploads and production deploys.

Root `wrangler.toml` is the source template Thunder uses to generate the deploy config at `_build/default/deploy/wrangler.toml`.

Create a Cloudflare API token and export it:

```bash
export CLOUDFLARE_API_TOKEN="<your-token>"
```

Set your Cloudflare account id in `wrangler.toml`:

```toml
account_id = "<your-cloudflare-account-id>"
```

You can find your account id with:

```bash
npx wrangler whoami
```

Optional (for CI/overrides), you can also export:

```bash
export CLOUDFLARE_ACCOUNT_ID="<your-cloudflare-account-id>"
```

Recommended token capability:

- permissions sufficient for Worker version upload and deploy for your target account/script.

If `CLOUDFLARE_API_TOKEN` is missing:

- `dune build` still succeeds,
- preview publish is skipped with a clear message.

## Build And Deploy Workflows

### Normal build + preview behavior

```bash
dune build
```

What happens:

1. `@worker-build` generates worker artifacts.
2. Thunder stages a deploy-ready tree under `_build/default/deploy/`.
3. Preview pipeline computes artifact hash.
4. If unchanged, upload is skipped.
5. If changed and token is present, Wrangler upload runs against the generated deploy config.
6. Metadata is written to `.thunder/preview.json`.

### Force preview upload

```bash
THUNDER_FORCE_PREVIEW=1 dune build
```

### Explicit production deploy

```bash
CONFIRM_PROD_DEPLOY=1 dune build @deploy-prod
```

Without `CONFIRM_PROD_DEPLOY=1`, production deploy fails safely.

## Artifact Layout

- build artifact module: `_build/default/dist/worker/thunder_runtime.mjs`
- build artifact Wasm chunks: `_build/default/dist/worker/thunder_runtime.assets/*.wasm`
- generated deploy config: `_build/default/deploy/wrangler.toml`
- generated deploy runtime host: `_build/default/deploy/worker_runtime/index.mjs`
- preview metadata: `.thunder/preview.json`

## Preview Metadata Fields

Current metadata keys may include:

- `artifact_hash`
- `last_upload_at`
- `last_version_id`
- `last_preview_url`
- `raw_wrangler_output`

Legacy metadata using `hash=...` is still read for compatibility.

## Local Validation Commands

- `.mli` policy: `bash scripts/check_mli.sh`
- build: `dune build`
- tests: `dune runtest`
- docs: `dune build @doc` (requires `odoc`)
- worker artifacts only: `dune build @worker-build`

## Examples

- `examples/hello_site`
- `examples/json_api`
- `examples/cookies`
- `examples/params`
- `examples/middleware`
- `examples/env_binding`

## Troubleshooting

- `Program odoc not found`:
  - install with `opam install odoc`.
- preview upload skipped due to token:
  - export `CLOUDFLARE_API_TOKEN` in your shell/CI.
- preview/deploy fails with account/auth errors:
  - verify `account_id` in `wrangler.toml` matches your Cloudflare account.
- deploy/runtime module path errors:
  - run `dune build` and confirm `_build/default/deploy/` contains staged Worker files.
- `Wrangler not available`:
  - run `npm install` and ensure local wrangler is available.
- runtime initialization/ABI errors:
  - verify `dune build @worker-build` generated both `thunder_runtime.mjs` and `thunder_runtime.assets/*.wasm`.

## MVP Limitations

- Buffered body only.
- No streaming response API.
- No multipart parser.
- No WebSockets.
- Cloudflare Workers target only.

## Additional Docs

- `docs/architecture.md`
- `docs/supported_features.md`
- `docs/deployment.md`
- `docs/examples.md`
- `docs/release_checklist.md`
