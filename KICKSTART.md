# Thunder Kickstart

This guide takes you from "I want to try Thunder" to a working app and Cloudflare deploy path.

Preferred path: generate a new Thunder app first.

Planned install shape:

```bash
curl -fsSL https://.../install.sh | bash
thunder doctor
thunder new my-app
cd my-app
```

`thunder doctor` should report a valid Thunder binary, a resolved framework home, and the local tools Thunder expects.

If `thunder` is still not found after install, add `~/.local/bin` to your `PATH` using the command printed by the installer.

The rest of this document has two parts:

1. generated-app flow for people trying Thunder
2. repo-dogfood flow for contributors working inside the Thunder framework repo itself

At this point Thunder's generated-app workflow is real and working. The main unfinished piece is the final installation/distribution story for Thunder itself; generated apps currently include a temporary framework link while that is being finalized.

## Generated App Flow

### 1) Create a new app

```bash
thunder doctor
thunder new my-app
cd my-app
```

### 2) Install app dependencies

```bash
npm install
```

Prerequisites for generated apps are the same core tools Thunder uses today:

- OCaml + opam + dune
- Node.js + npm
- CMake + Ninja (for the `wasm_of_ocaml` toolchain)
- Linux/CI may also require `binaryen` (`wasm-merge`) for the `wasm_of_ocaml` toolchain

### 3) Edit your app code

Start here:

- `app/routes.ml`
- `app/middleware.ml`
- `worker/entry.ml`

For most users:

- edit `app/routes.ml`
- leave `worker/entry.ml` alone unless you are changing app wiring

### 4) Build the app

```bash
dune build
```

What this does:

- builds Worker artifacts
- stages the deploy-ready tree
- uploads a preview if Cloudflare credentials are present and the artifact hash changed

Preview metadata is written to:

- `.thunder/preview.json`

If you are developing Thunder itself and want to verify the current generated-app experience from the framework repo, run:

```bash
bash scripts/verify_generated_app_fixture.sh
```

### 5) Worker-only build

```bash
dune build @worker-build
```

### 6) Explicit production deploy

```bash
CONFIRM_PROD_DEPLOY=1 dune build @deploy-prod
```

### 7) Preview smoke validation

```bash
THUNDER_SMOKE_WORKER_NAME="your-existing-worker" bash scripts/preview_smoke.sh auto
```

### 8) Know the current limitation

Generated apps currently include a temporary framework link under:

- `vendor/thunder-framework`

With the current release direction, that workspace-visible path is expected to become a link into the installed framework home created by the Thunder installer.

## Framework Repo Dogfood Flow

Important: the app Thunder deploys from this repo lives in `packages/thunder_worker/wasm_entry.ml`. The `examples/*` apps are reference examples for learning the API; they are not the deployed app by default.

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
- Binaryen on Linux/CI (provides `wasm-merge` used by the toolchain)

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
- `compatibility_flags = ["nodejs_compat"]` remains enabled for the current generated runtime output

Thunder uses this root file as a template and generates the actual deploy config at `_build/default/deploy/wrangler.toml`.

Find your account id with:

```bash
npx wrangler whoami
```

## 7) Build your first test app

Thunder deploys the route list defined in:

- `packages/thunder_worker/wasm_entry.ml`

Start by editing the `Router.router [ ... ]` list in that file.

Minimal example:

```ocaml
let app =
  Router.router
    [
      Router.get "/"
        (Handler.handler (fun _ -> Response.html "<h1>Hello from Thunder</h1>"));
      Router.get "/health"
        (Handler.handler (fun _ -> Response.json "{\"ok\":true}"));
    ]
```

Good first routes to add while learning:

- `/` for HTML output
- `/health` for a simple JSON check
- `/echo` for request body testing

## 8) Know what not to edit

Important:

- `worker_runtime/index.mjs` is runtime bridge code (request/response adapter), not where app routes are authored.
- `worker_runtime/app_abi.mjs` and `worker_runtime/compiled_runtime_backend.mjs` are Thunder runtime internals, not app code.
- `examples/*` are reference apps for local learning, not wired into deploy by default.
- `_build/default/` files are generated outputs; do not hand-edit them.

## 9) Validate repo health locally

```bash
bash scripts/check_mli.sh
dune build
dune runtest
```

`dune build` also triggers preview logic; without `CLOUDFLARE_API_TOKEN`, preview upload is skipped non-fatally.

It also stages a deploy-ready Worker tree under `_build/default/deploy/`, which is what Thunder points Wrangler at for preview and production deploys.

If preview upload prints `version_id=...` but says preview URL was not found, upload still succeeded; only URL parsing from Wrangler output was missing.

## 10) Understand what `dune build` produces

`dune build` already does the normal thing you want:

- builds the OCaml app runtime
- stages the deploy-ready Worker tree
- uploads a preview when deployable artifacts changed and credentials are present

If you only want the deploy artifacts without the preview step, use:

```bash
dune build @worker-build
```

## 11) Build deployable worker artifacts

```bash
dune build @worker-build
```

Expected outputs are under `_build/default/dist/worker/`:

- `thunder_runtime.mjs`
- `thunder_runtime.assets/*.wasm`
- `manifest.json`

Expected deploy-ready files are under `_build/default/deploy/`:

- `wrangler.toml`
- `worker_runtime/index.mjs`
- `worker_runtime/app_abi.mjs`
- `worker_runtime/compiled_runtime_backend.mjs`
- `worker_runtime/compiled_runtime_bootstrap.mjs`
- `dist/worker/thunder_runtime.mjs`
- `dist/worker/manifest.json`
- `dist/worker/thunder_runtime.assets/*.wasm`

## 12) Preview smoke validation

Before production deploy, validate the runtime path against an existing Worker you control:

```bash
THUNDER_SMOKE_WORKER_NAME="your-existing-worker" bash scripts/preview_smoke.sh auto
```

This uploads a preview version and checks the current default routes (`/`, `/health`, `/echo`, `/missing`).

## 13) Deploy to production (explicit)

```bash
CONFIRM_PROD_DEPLOY=1 dune build @deploy-prod
```

Production deploy is intentionally guarded and will fail safely if `CONFIRM_PROD_DEPLOY` is not set to `1`.

## 14) Verify deployment

Use Wrangler output URL, or inspect deployments:

```bash
npx wrangler whoami
npx wrangler deployments list
```

Then open your Worker URL in a browser and hit `/`.

Tip: if preview URL parsing is missing in CLI output, inspect `.thunder/preview.json` (`last_version_id`, `raw_wrangler_output`) and use `npx wrangler deployments list`.

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
- deploy tree missing or stale: run `dune build` and inspect `_build/default/deploy/`
- preview smoke needs an existing Worker name: set `THUNDER_SMOKE_WORKER_NAME`
- deployed app is not the example you edited: make sure you changed `packages/thunder_worker/wasm_entry.ml`
