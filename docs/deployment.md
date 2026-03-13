# Deployment

## Build outputs

- Compiled OCaml runtime artifact: `_build/default/dist/worker/thunder_runtime.mjs` (generated via `wasm_of_ocaml`)
- Companion Wasm chunks: `_build/default/dist/worker/thunder_runtime.assets/*.wasm`
- Build manifest: `_build/default/dist/worker/manifest.json`
- Generated deploy config: `_build/default/deploy/wrangler.toml`
- Generated Worker runtime host: `_build/default/deploy/worker_runtime/index.mjs`
- Generated Worker ABI shim: `_build/default/deploy/worker_runtime/app_abi.mjs`
- Generated compiled runtime backend: `_build/default/deploy/worker_runtime/compiled_runtime_backend.mjs`
- Preview metadata: `.thunder/preview.json`

Thunder deploys the app defined in `packages/thunder_worker/wasm_entry.ml` and packages the generated runtime around it.

## Dune aliases

- `@worker-build`: builds deployable artifacts.
- `@preview-publish`: computes artifact hash and publishes preview when changed.
- `@deploy-prod`: explicit production deploy path.

## Preview flow

`dune build` triggers `@worker-build` and `@preview-publish`.

Root `wrangler.toml` is the source template Thunder uses to generate `_build/default/deploy/wrangler.toml`.

It should include your Cloudflare account id:

```toml
account_id = "<your-cloudflare-account-id>"
compatibility_flags = ["nodejs_compat"]
```

Find your account id with `npx wrangler whoami`.

Preview publish behavior:

1. Validate artifacts exist.
2. Read `dist/worker/manifest.json` as the source of truth for deployable runtime files.
3. Stage a deploy-ready Worker tree under `_build/default/deploy/` from the manifest.
4. Compute stable hash from the manifest plus all referenced artifacts.
5. Compare with previous metadata hash.
6. Skip upload if unchanged (unless forced).
7. Upload preview via Wrangler using the generated deploy config.

In the normal developer workflow, `dune build` is enough; use `@worker-build` only when you want artifacts without the preview step.

Preview metadata format (`.thunder/preview.json`, line-based key/value):

- `artifact_hash`
- `last_upload_at`
- `last_version_id`
- `last_preview_url`
- `raw_wrangler_output`

Backward compatibility:

- legacy `hash=...` metadata is still read and migrated in-memory to `artifact_hash` semantics.

Force preview mode:

- Set `THUNDER_FORCE_PREVIEW=1`.

Preview output parsing:

- Thunder parses Wrangler output for version id and preview URL.
- If parsing fails, preview upload is still considered successful and `raw_wrangler_output` is persisted for debugging.

Troubleshooting:

- If `CLOUDFLARE_API_TOKEN` is unset, preview publish is skipped (non-fatal).
- If `account_id` is missing/incorrect, Wrangler preview/deploy can fail with account/authentication errors.
- If Wrangler is unavailable, preview publish is skipped (non-fatal).
- If artifacts are missing, preview publish fails with explicit missing path errors.
- Preview runtime now uses a single compiled-runtime path; if smoke fails, investigate the staged runtime files rather than backend selection.

## Preview smoke workflow

- Manual GitHub Action: `.github/workflows/preview-smoke.yml`
- Local smoke script: `scripts/preview_smoke.sh [auto]`
- The smoke path expects `CLOUDFLARE_API_TOKEN` and records preview metadata in `.thunder/preview.json`.
- Use `docs/runtime_parity_matrix.md` to compare route behavior before advancing toward Phase 19.
- Phase 18 canary validation has been exercised against an existing Worker on the single compiled-runtime path.

Smoke route expectations:

- `/` returns the default HTML page
- `/health` returns `{"ok":true}`
- `/echo` returns the posted JSON body
- `/missing` returns `404`

## Production deploy

Run:

`CONFIRM_PROD_DEPLOY=1 dune build @deploy-prod`

Production deploy fails safely when confirmation is missing.

Thunder runs Wrangler against `_build/default/deploy/wrangler.toml`, not the root template directly.
