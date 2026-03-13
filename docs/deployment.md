# Deployment

## Build outputs

- Compiled OCaml runtime artifact: `_build/default/dist/worker/thunder_runtime.mjs` (generated via `wasm_of_ocaml`)
- Companion Wasm chunks: `_build/default/dist/worker/thunder_runtime.assets/*.wasm`
- Generated deploy config: `_build/default/deploy/wrangler.toml`
- Generated Worker runtime host: `_build/default/deploy/worker_runtime/index.mjs`
- Preview metadata: `.thunder/preview.json`

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
```

Find your account id with `npx wrangler whoami`.

Preview publish behavior:

1. Validate artifacts exist.
2. Stage a deploy-ready Worker tree under `_build/default/deploy/`.
3. Compute stable hash.
4. Compare with previous metadata hash.
5. Skip upload if unchanged (unless forced).
6. Upload preview via Wrangler using the generated deploy config.

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

## Production deploy

Run:

`CONFIRM_PROD_DEPLOY=1 dune build @deploy-prod`

Production deploy fails safely when confirmation is missing.

Thunder runs Wrangler against `_build/default/deploy/wrangler.toml`, not the root template directly.
