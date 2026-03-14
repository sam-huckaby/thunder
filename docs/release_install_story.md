# Release And Install Layout

This document describes the Thunder install layout and what a Thunder installation provides to generated apps.

## Installed Locations

Thunder uses these locations for the installed CLI and framework home:

- `~/.local/bin/thunder`
- `~/.local/share/thunder/versions/<version>/`
- `~/.local/share/thunder/current`

The `thunder` binary is installed in the user bin directory. Framework-owned assets live in the versioned framework home. The `current` path points at the active installed version.

## User Flow

The install and app-creation flow is:

```bash
curl -fsSL https://.../install.sh | bash
thunder doctor
thunder new my-app
cd my-app
npm install
dune build
```

`thunder doctor` validates the local Thunder binary, framework-home resolution, and required local tools.

## What A Thunder Installation Provides

The Thunder binary is only one part of the installed system. Generated apps also depend on framework-owned runtime and build assets.

An installation provides:

- framework OCaml packages used by generated app builds
- runtime JavaScript modules from `worker_runtime/`
- helper scripts such as `scripts/generate_wasm_asset_map.py`
- CLI templates used by `thunder new` and `thunder init`

## Framework Files In Generated Apps

Generated apps expose framework-owned assets through:

- `vendor/thunder-framework`

Thunder uses that workspace-visible path so generated apps can resolve the framework runtime files, build helpers, and templates they need for local builds and deploys.

That framework path provides four categories of files:

1. framework OCaml packages
   - `packages/thunder_core`
   - `packages/thunder_http`
   - `packages/thunder_router`
   - `packages/thunder_worker`
   - `packages/thunder_cli`
2. runtime JavaScript modules
   - `worker_runtime/index.mjs`
   - `worker_runtime/app_abi.mjs`
   - `worker_runtime/compiled_runtime_backend.mjs`
   - `worker_runtime/compiled_runtime_bootstrap.mjs`
3. build and deploy helper scripts
   - `scripts/generate_wasm_asset_map.py`
   - smoke and helper scripts
4. Dune metadata needed to compile the framework pieces used by generated apps

## Installer Script

Thunder includes an installer script at:

- `scripts/install_thunder.sh`

The installer script:

- installs the Thunder CLI executable into `~/.local/bin/thunder`
- installs framework assets into `~/.local/share/thunder/versions/<version>/`
- updates `~/.local/share/thunder/current`
- supports `thunder doctor` as a post-install verification step
- prints PATH guidance when `~/.local/bin` is not already on `PATH`

## Generated App Compatibility

The generated app workflow depends on the installed framework layout matching the framework-owned paths Thunder expects.

That means the installed framework home must provide:

- the OCaml packages referenced by generated app builds
- the Worker runtime modules used for staging and deployment
- the helper scripts used during artifact generation
- the scaffolding templates used for app creation

When those files are present, the generated app commands work against the installed framework layout:

- `thunder new my-app`
- `dune build @worker-build`
- `dune build`
- `dune build @deploy-prod`

## Verification

Useful verification steps are:

```bash
thunder doctor
thunder new my-app
cd my-app
npm install
dune build @worker-build
dune build
```

At the framework-repo level, `scripts/verify_generated_app_fixture.sh` provides an end-to-end generated-app verification path.

## Why This Layout Exists

Thunder-generated apps depend on both app-owned files and framework-owned files.

The app owns:

- `app/routes.ml`
- `app/middleware.ml`
- `worker/entry.ml`
- `wrangler.toml`
- `thunder.json`

Thunder owns:

- runtime host modules
- ABI bridge modules
- build helper scripts
- scaffolding templates
- deploy staging logic

The installed framework home gives generated apps a stable place to resolve those framework-owned pieces while keeping application code in the app workspace.
