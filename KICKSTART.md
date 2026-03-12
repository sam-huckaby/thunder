# Thunder Kickstart

This guide takes you from "just cloned" to "deployed on Cloudflare Workers".

Note: with the current repo wiring, deploy uses the built-in Thunder runtime entrypoint app. The `examples/hello_site` example demonstrates the same API shape locally.

## 1) Clone and enter the repo

```bash
git clone <your-repo-url> thunder
cd thunder
```

## 2) Install prerequisites

You need:

- OCaml + opam + dune
- Node.js + npm
- CMake + Ninja (required by `wasm_of_ocaml` toolchain)

macOS example:

```bash
brew install opam node cmake ninja
```

## 3) Initialize opam and install OCaml deps

If you do not already have an active switch:

```bash
opam switch create 5.2.0
eval "$(opam env)"
```

Install required packages:

```bash
opam install -y dune wasm_of_ocaml-compiler odoc
```

## 4) Install Node dependencies

```bash
npm install
```

This provides local Wrangler via npm scripts/bin.

## 5) Authenticate to Cloudflare

Use one of these:

### Option A: Interactive login

```bash
npx wrangler login
```

### Option B: API token

```bash
export CLOUDFLARE_API_TOKEN="<your-token>"
```

Token should allow Worker version upload/deploy for your account/script.

## 6) Check worker config

Open `wrangler.toml` and verify:

- `name` is your desired worker name
- `main = "worker_runtime/index.mjs"`
- `account_id = "<your-cloudflare-account-id>"` is set to your real account id

Find your account id with:

```bash
npx wrangler whoami
```

## 7) Validate repo health locally

```bash
bash scripts/check_mli.sh
dune build
dune runtest
```

`dune build` also triggers preview logic; without `CLOUDFLARE_API_TOKEN`, preview upload is skipped non-fatally.

## 8) Build deployable worker artifacts

```bash
dune build @worker-build
```

Expected outputs are under `_build/default/dist/worker/`:

- `thunder_runtime.mjs`
- `thunder_runtime.assets/*.wasm`

## 9) Deploy to production (explicit)

```bash
CONFIRM_PROD_DEPLOY=1 dune build @deploy-prod
```

Production deploy is intentionally guarded and will fail safely if `CONFIRM_PROD_DEPLOY` is not set to `1`.

## 10) Verify deployment

Use Wrangler output URL, or inspect deployments:

```bash
npx wrangler whoami
npx wrangler deployments list
```

Then open your Worker URL in a browser and hit `/`.

## Useful commands

```bash
# Full local validation
bash scripts/check_mli.sh && dune build && dune runtest

# Force preview upload on build even if artifact hash is unchanged
THUNDER_FORCE_PREVIEW=1 dune build

# Build docs
dune build @doc
```

## Troubleshooting

- `Program odoc not found`: run `opam install odoc`
- preview skipped due to token: export `CLOUDFLARE_API_TOKEN`
- account/auth errors on upload/deploy: verify `account_id` in `wrangler.toml` matches your Cloudflare account
- wrangler missing: run `npm install`
- worker artifacts missing: run `dune build @worker-build`
