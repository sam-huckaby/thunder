# Install Context Notes

Thunder currently still runs from its framework monorepo, but the path to `thunder new my-app` requires the CLI/runtime code to stop assuming repo-root-relative paths.

## Current assumptions

Today Thunder CLI defaults still assume an app-like workspace contains:

- `dist/worker/thunder_runtime.mjs`
- `dist/worker/manifest.json`
- `dist/worker/thunder_runtime.assets/`
- `wrangler.toml`
- a generated deploy tree rooted at `deploy/`

Those assumptions are now centralized in `packages/thunder_cli/project_layout.ml` so later phases can replace them with install-context-aware resolution without having to redesign every CLI command first.

Current framework-root discovery order:

1. `THUNDER_FRAMEWORK_ROOT` when it points at a valid Thunder runtime root
2. current working directory ancestors
3. Thunder executable directory ancestors
4. `OPAM_SWITCH_PREFIX/share/thunder` and `OPAM_SWITCH_PREFIX/share/thunder-cloudflare`

This is still an intermediate step, but it means Thunder no longer depends only on a manually supplied framework root.

## `thunder.json`

The generated-app direction introduces a Thunder-owned app config file:

- `thunder.json`

The current initial shape is intentionally small and focused on path ownership:

```json
{
  "app_module": "My_app.Routes",
  "worker_entry_path": "worker/entry.ml",
  "compiled_runtime_path": "dist/worker/thunder_runtime.mjs",
  "wrangler_template_path": "wrangler.toml",
  "deploy_dir": "deploy"
}
```

Today Thunder CLI reads this file when present and uses it to override default app-relative path assumptions.

This is the first step toward making generated apps describe their own layout explicitly instead of relying on the framework monorepo shape.

## Temporary framework link

Until Thunder's final install/distribution story is settled, `thunder new` now links or copies a temporary framework bundle into:

- `vendor/thunder-framework`

That temporary framework link gives the generated app enough framework source/runtime material to:

- resolve Thunder libraries in Dune
- build `@worker-build`

This is an intermediate development step, not the intended final product experience.

Current status:

- the generated app scaffold now uses a temporary framework link plus local runtime files
- `dune build @worker-build` succeeds in the generated app
- plain `dune build` also succeeds when `CLOUDFLARE_API_TOKEN` is absent, with preview publish skipping non-fatally
- credentialed preview upload from a fresh generated app also works when pointed at an existing Worker and a valid account id
- generated app preview metadata now lands at app-root `.thunder/preview.json`

Remaining install-context work is now about replacing the temporary framework-link approach with the final install/distribution model.

The first implementation of that direction is now in place via `scripts/install_thunder.sh`, which installs:

- `~/.local/bin/thunder`
- `~/.local/share/thunder/versions/<version>/`
- `~/.local/share/thunder/current`

Current intended release path:

- generated apps keep using `vendor/thunder-framework` as the workspace-visible path
- the installer-backed flow makes that path a link into `~/.local/share/thunder/current`
- that preserves the working generated-app Dune/runtime shape while removing the need to copy framework internals into every app

That makes the current release-shaping question very focused:

- keep the generated app layout and UX as-is
- replace the temporary framework home with the final install/distribution path
- ensure the same `dune build`, preview, and deploy ergonomics survive that change

That means Phase F4 can focus on scaffold quality and generated-app ergonomics, while Phase F5 and later phases can move the generated app from "works with a vendored temporary framework bundle" to the final installable-framework model.

## Why this matters

When Thunder becomes an installed framework instead of a cloned repo:

- runtime JS files will come from the installed Thunder package
- scaffolding templates will come from the installed Thunder package
- generated apps will own their own `wrangler.toml`, `dune-project`, and app source

That means runtime asset lookup and staging must be able to resolve:

- app-owned paths
- framework-owned installed asset paths
- generated deploy output paths

## Phase F3 objective

Phase F3 converts these assumptions into a real install-context story so Thunder can run correctly outside the framework monorepo.

## Current generated-app blocker

The first `thunder new` scaffold now writes a plausible app layout, but a fresh generated app still depends on Thunder libraries being discoverable by Dune as installed/public packages.

At the moment, trying `dune build @worker-build` in a generated app without a finalized installation story fails at package resolution (`thunder.worker` not found).

That is the current concrete blocker between the first scaffold slice and a truly self-sufficient generated app.
