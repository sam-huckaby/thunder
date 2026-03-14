# Release / Install Story

This document captures the current preferred release direction for Thunder while Phase F7 is in progress.

## Preferred direction

Initial Thunder installation should be driven by a curl-installed binary rather than opam.

Working first implementation direction:

- install `thunder` into `~/.local/bin/thunder`
- install framework assets into `~/.local/share/thunder/versions/<version>/`
- point `~/.local/share/thunder/current` at the active version
- let generated apps reference that installed framework home instead of carrying a full copied framework bundle

Target user flow:

```bash
curl -fsSL https://.../install.sh | bash
thunder doctor
thunder new my-app
cd my-app
npm install
dune build
```

## What the installed binary must provide

The Thunder binary is not enough by itself. The generated app currently depends on framework-owned runtime and source assets.

Today those assets are exposed to generated apps through:

- `vendor/thunder-framework`

In the final model, that workspace-visible path can become a symlink into the installed framework home. To remove the temporary bundled copy cleanly, the installed Thunder distribution must make the following available in a stable location:

- framework OCaml package sources or installed package artifacts needed for generated app builds
- runtime JS files from `worker_runtime/`
- helper scripts such as `generate_wasm_asset_map.py`
- CLI templates used by `thunder new` / `thunder init`

## What `vendor/thunder-framework` currently contains

The temporary framework bundle currently provides four categories of things:

1. framework OCaml packages
   - `packages/thunder_core`
   - `packages/thunder_http`
   - `packages/thunder_router`
   - `packages/thunder_worker`
   - `packages/thunder_cli`
2. runtime JS modules
   - `worker_runtime/index.mjs`
   - `worker_runtime/app_abi.mjs`
   - `worker_runtime/compiled_runtime_backend.mjs`
   - `worker_runtime/compiled_runtime_bootstrap.mjs`
3. build/deploy helper scripts
   - `scripts/generate_wasm_asset_map.py`
   - smoke / helper scripts
4. enough Dune metadata to compile the framework pieces used by generated apps

That means replacing `vendor/thunder-framework` with a link into an installed framework home still requires all four categories to exist in the installed location.

## Practical replacement options

### Option A: install binary + shared framework home

The installer places:

- `thunder` binary in a user bin dir
- framework assets in something like `~/.local/share/thunder/`

Generated apps would then point `framework_root` at that installed location instead of relying on the temporary local framework-home bundle.

Pros:

- closest to current architecture
- easiest incremental replacement for the temporary framework-home bundle
- works well with curl-installed binary

Cons:

- still requires a framework asset home on disk
- version skew between app and installed framework must be managed carefully

### Option B: binary owns embedded templates + runtime assets

The binary embeds:

- templates
- runtime JS assets
- helper scripts or equivalent generated logic

It materializes what is needed into the generated app during `thunder new`.

Pros:

- simpler install surface for users
- fewer moving pieces in the user environment

Cons:

- generated apps may still end up with copied framework internals unless the build story is redesigned
- binary release gets larger and more coupled to runtime asset changes

### Option C: binary install + proper installed OCaml packages

The curl-installed binary handles CLI/scaffolding, while Thunder libraries are installed through a second mechanism.

Pros:

- cleaner separation between CLI and libraries

Cons:

- more complicated user story
- contradicts the goal of a very simple initial install path

## Current recommendation

For the first release-quality Thunder UX, the best fit is:

- curl-installed `thunder` binary
- installed shared framework home on disk
- generated apps reference that installed framework home through a workspace-visible link instead of relying on a copied local framework bundle

This keeps the current generated-app architecture mostly intact while replacing copied framework internals with an installed framework home plus a workspace-visible link.

Concretely, the generated app can keep referencing:

- `vendor/thunder-framework`

while the installer makes that path point at:

- `~/.local/share/thunder/current`

That lets us preserve the current Dune/runtime layout that already works.

## First implementation artifact

Thunder now includes an initial installer script:

- `scripts/install_thunder.sh`

Current behavior:

- installs the built Thunder CLI executable into `~/.local/bin/thunder`
- installs framework assets into `~/.local/share/thunder/versions/<version>/`
- updates `~/.local/share/thunder/current`
- supports `thunder doctor` as a quick post-install validation step

This script currently assumes it is being run from the Thunder source tree with a built CLI executable available. It is the first implementation step toward the eventual curl-installed release flow.

Current verification status:

- install into temporary `THUNDER_BIN_DIR` and `THUNDER_HOME`
- run installed `thunder new my-app`
- verify generated app `dune build @worker-build`
- verify generated app plain `dune build` with preview skipping non-fatally when credentials are absent

## Remaining work to replace the temporary `vendor/thunder-framework` bundle

1. define the installed framework-home layout
2. make `thunder new` write `thunder.json` against that layout
3. update generated-app Dune templates to reference installed framework assets instead of vendored ones
4. verify:
   - `dune build @worker-build`
   - plain `dune build`
   - preview publish
   - explicit deploy
5. change scaffolding from copying framework contents to linking the generated app to the installed framework home

## Non-goal right now

This document does not decide the final long-term package manager story for Thunder libraries. It only captures the most practical path for the first release-ready framework UX.
