# Deployment

## Build outputs

- Compiled OCaml runtime artifact: `dist/worker/thunder_runtime.mjs` (generated via `wasm_of_ocaml`)
- Companion Wasm chunks: `dist/worker/thunder_runtime.assets/*.wasm`
- Worker runtime host: `worker_runtime/index.mjs`
- Preview metadata: `.thunder/preview.json`

## Dune aliases

- `@worker-build`: builds deployable artifacts.
- `@preview-publish`: computes artifact hash and publishes preview when changed.
- `@deploy-prod`: explicit production deploy path.

## Preview flow

`dune build` triggers `@worker-build` and `@preview-publish`.

`wrangler.toml` should include your Cloudflare account id:

```toml
account_id = "<your-cloudflare-account-id>"
```

Find your account id with `npx wrangler whoami`.

Preview publish behavior:

1. Validate artifacts exist.
2. Compute stable hash.
3. Compare with previous metadata hash.
4. Skip upload if unchanged (unless forced).
5. Upload preview via Wrangler when changed.

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
