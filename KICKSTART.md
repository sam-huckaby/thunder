# Thunder Kickstart

This guide takes you from a fresh Thunder project to a working app and Cloudflare deploy flow.

## 1. Prerequisites

You need:

- OCaml + opam + dune
- Node.js + npm
- `wasm_of_ocaml-compiler`
- CMake + Ninja
- Linux/CI may also require `binaryen` for `wasm-merge`

Optional:

- `odoc` for local docs builds

Example setup:

```bash
opam install dune wasm_of_ocaml-compiler odoc
```

## 2. Create a new app

```bash
thunder new my-app
cd my-app
```

**Tip:** `thunder doctor` checks the Thunder installation and local toolchain.

## 3. Install app dependencies

```bash
npm install
```

This installs Wrangler and the Node-side dependencies used by the generated app.

## 4. Edit your app

Start with:

- `app/routes.ml`
- `app/middleware.ml`
- `worker/entry.ml`

In most apps, the main file you edit is `app/routes.ml`.

The generated `worker/entry.ml` stays small and exports your app through Thunder's Worker entrypoint.

## 5. Build the app

```bash
dune build
```

This build:

1. compiles the app to Worker runtime artifacts
2. stages a deploy-ready Worker tree
3. uploads a preview if Cloudflare credentials are present and the artifact hash changed

Preview metadata is written to:

- `.thunder/preview.json`

## 6. Configure Cloudflare

Set a Cloudflare API token:

```bash
export CLOUDFLARE_API_TOKEN="<your-token>"
```

Set your Cloudflare account id in `wrangler.toml`:

```toml
account_id = "<your-cloudflare-account-id>"
compatibility_flags = ["nodejs_als"]
```

If your app already uses broader Node compatibility, `nodejs_compat` also works. Thunder's request-context propagation only requires `nodejs_als`.

Find your account id with:

```bash
npx wrangler whoami
```

If `CLOUDFLARE_API_TOKEN` is not set, `dune build` still succeeds and preview upload is skipped.

For supported dev/test setup, Thunder's intended flow is now:

```bash
thunder cloudflare provision
thunder cloudflare status
thunder cloudflare status --pretty
```

`thunder cloudflare status` returns JSON by default so CI and agents can inspect it directly.

## 7. Useful commands

Build runtime artifacts only:

```bash
dune build @worker-build

# explicit Wasm build
THUNDER_COMPILE_TARGET=wasm dune build @worker-build
```

Run tests:

```bash
dune runtest
```

Provision or inspect Cloudflare resources:

```bash
thunder cloudflare provision
thunder cloudflare status
thunder cloudflare status --pretty
```

Force a preview upload:

```bash
THUNDER_FORCE_PREVIEW=1 dune build
```

Explicit production deploy:

```bash
CONFIRM_PROD_DEPLOY=1 dune build @deploy-prod
```

Preview smoke validation:

```bash
THUNDER_SMOKE_WORKER_NAME="your-existing-worker" bash scripts/preview_smoke.sh js
THUNDER_SMOKE_WORKER_NAME="your-existing-worker" bash scripts/preview_smoke.sh wasm
```

## 8. What Thunder builds

The main generated outputs are:

- `_build/default/dist/worker/thunder_runtime.mjs`
- `_build/default/dist/worker/manifest.json`
- `_build/default/dist/worker/thunder_runtime.assets/` when the selected target is `wasm`
- `_build/default/deploy/wrangler.toml`
- `_build/default/deploy/worker_runtime/index.mjs`
- `_build/default/deploy/worker_runtime/app_abi.mjs`
- `_build/default/deploy/worker_runtime/compiled_runtime_backend.mjs`
- `.thunder/preview.json`

## 9. Generated app layout

The files you will work with most often are:

- `app/routes.ml`
- `app/middleware.ml`
- `worker/entry.ml`
- `wrangler.toml`
- `thunder.json`

Thunder also places framework-owned runtime and packaging pieces in the generated app so the app can build and deploy with the Thunder toolchain.

## 10. Cloudflare bindings through Thunder

Thunder exposes Cloudflare-specific wrappers through `Thunder.Worker.*`, so app code can stay inside the main Thunder API surface.

Examples include:

- `Thunder.Worker.KV`
- `Thunder.Worker.R2`
- `Thunder.Worker.D1`
- `Thunder.Worker.Queues`
- `Thunder.Worker.AI`
- `Thunder.Worker.Service`
- `Thunder.Worker.Durable_object`
- `Thunder.Worker.Generic`

See `docs/examples.md` for example binding names and `wrangler.toml` snippets.

## 11. Working on the framework repo

If you are developing Thunder itself from this repository, use the repo root commands:

```bash
npm install
dune build
dune runtest
bash scripts/check_mli.sh
bash scripts/verify_generated_app_fixture.sh
```

The app deployed from the framework repo is defined in `packages/thunder_worker/wasm_entry.ml`.

The `examples/` directory is for reference examples and local learning.

## 12. Troubleshooting

- `Program odoc not found`: run `opam install odoc`
- preview upload skipped: export `CLOUDFLARE_API_TOKEN`
- account/auth errors: verify `account_id` in `wrangler.toml`
- Wrangler missing: run `npm install`
- worker artifacts missing: run `dune build @worker-build`
- deploy tree missing: run `dune build` and inspect `_build/default/deploy/`
- preview smoke needs an existing Worker name: set `THUNDER_SMOKE_WORKER_NAME`

## 13. Next reading

- `docs/architecture.md`
- `docs/deployment.md`
- `docs/supported_features.md`
- `docs/examples.md`
