# Deployment

This document describes how Thunder builds, stages, previews, and deploys apps to Cloudflare Workers.

Thunder deploys a generated Worker runtime tree, not a raw OCaml artifact by itself. The deployable unit includes the compiled OCaml runtime bundle, Wasm assets, the Thunder Worker host, the ABI shim, and a generated Wrangler config.

## Deployment Inputs And Outputs

The main build outputs are:

- `_build/default/dist/worker/thunder_runtime.mjs`
- `_build/default/dist/worker/thunder_runtime.assets/*.wasm`
- `_build/default/dist/worker/manifest.json`
- `_build/default/deploy/wrangler.toml`
- `_build/default/deploy/worker_runtime/index.mjs`
- `_build/default/deploy/worker_runtime/app_abi.mjs`
- `_build/default/deploy/worker_runtime/compiled_runtime_backend.mjs`
- `_build/default/deploy/worker_runtime/compiled_runtime_bootstrap.mjs`
- `.thunder/preview.json`

In a generated app, Thunder deploys the app exported from `worker/entry.ml`.

In the framework repository, Thunder deploys the app exported from `packages/thunder_worker/wasm_entry.ml`.

## Dune Aliases

- `@worker-build`
  - builds the runtime artifacts and manifest
- `@preview-publish`
  - stages the deploy tree and uploads a preview when needed
- `@deploy-prod`
  - stages the deploy tree and performs an explicit production deploy

For normal app development, `dune build` is the standard entrypoint.

## Normal Build Flow

```bash
dune build
```

That build runs the normal Thunder deployment pipeline:

1. build the Worker runtime artifacts
2. read `dist/worker/manifest.json`
3. stage a deploy-ready Worker tree under `_build/default/deploy/`
4. compute an artifact hash from the manifest and referenced files
5. compare the hash with `.thunder/preview.json`
6. skip preview upload if nothing changed
7. upload a preview through Wrangler when credentials are present and artifacts changed

If `CLOUDFLARE_API_TOKEN` is not set, the build still succeeds and preview upload is skipped.

## Worker-Only Build

If you want deployable artifacts without the preview step:

```bash
dune build @worker-build
```

## Preview Publish

Thunder uses Wrangler version upload for preview environments.

The preview flow is driven by `dist/worker/manifest.json`, which is the source of truth for the runtime files Thunder stages and hashes.

Preview metadata is stored in `.thunder/preview.json` as line-based key/value data. The keys may include:

- `artifact_hash`
- `last_upload_at`
- `last_version_id`
- `last_preview_url`
- `raw_wrangler_output`

Force a preview upload even when the artifact hash is unchanged:

```bash
THUNDER_FORCE_PREVIEW=1 dune build
```

Thunder parses Wrangler output to capture version id and preview URL. If the upload succeeds but output parsing is incomplete, Thunder still records the raw Wrangler output for debugging.

## Production Deploy

Run:

```bash
CONFIRM_PROD_DEPLOY=1 dune build @deploy-prod
```

Production deploy is intentionally guarded. If `CONFIRM_PROD_DEPLOY` is not set to `1`, the deploy fails safely.

Thunder runs Wrangler against `_build/default/deploy/wrangler.toml`, not the root `wrangler.toml` template directly.

## Wrangler Configuration

Root `wrangler.toml` is the template Thunder uses to generate the staged deploy config.

It should include your Cloudflare account id:

```toml
account_id = "<your-cloudflare-account-id>"
compatibility_flags = ["nodejs_compat"]
```

Find your account id with:

```bash
npx wrangler whoami
```

The staged config is rendered so that:

- `main = "worker_runtime/index.mjs"`
- `find_additional_modules = true`

That makes the staged Worker host the deployed entrypoint.

## Preview Smoke Validation

Thunder includes a smoke path for validating preview deployments:

- local script: `scripts/preview_smoke.sh [auto]`
- GitHub workflow: `.github/workflows/preview-smoke.yml`

Local usage:

```bash
THUNDER_SMOKE_WORKER_NAME="your-existing-worker" bash scripts/preview_smoke.sh auto
```

The smoke script expects `CLOUDFLARE_API_TOKEN` and records preview metadata in `.thunder/preview.json`.

The default smoke expectations are:

- `/` returns the default HTML page
- `/health` returns `{"ok":true}`
- `/echo` returns the posted JSON body
- `/missing` returns `404`

## How Staging Works

Thunder stages deployment artifacts from the manifest rather than assuming a hardcoded deploy tree.

The staging flow:

1. parse `dist/worker/manifest.json`
2. resolve every referenced runtime file
3. copy those files into `_build/default/deploy/`
4. rewrite `wrangler.toml` for the staged Worker tree
5. point Wrangler at the staged config

This keeps preview and production deploys aligned around the same packaged runtime shape.

## Troubleshooting

- `CLOUDFLARE_API_TOKEN` unset
  - preview upload is skipped
- missing or incorrect `account_id`
  - Wrangler preview or deploy can fail with account/auth errors
- Wrangler unavailable
  - preview upload is skipped and production deploy cannot proceed
- missing runtime artifacts
  - run `dune build @worker-build`
- missing or stale deploy tree
  - run `dune build` and inspect `_build/default/deploy/`
- smoke validation failures
  - inspect the staged runtime files and `.thunder/preview.json`
