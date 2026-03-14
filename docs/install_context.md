# Install Context Notes

This document describes how Thunder resolves framework-owned files and app-owned files during scaffolding, building, staging, and deployment.

## Workspace Assumptions

Thunder CLI works with an app-shaped workspace that contains:

- `dist/worker/thunder_runtime.mjs`
- `dist/worker/manifest.json`
- `dist/worker/thunder_runtime.assets/`
- `wrangler.toml`
- a generated deploy tree rooted at `deploy/`

These defaults are centralized in `packages/thunder_cli/project_layout.ml`.

## Framework Root Discovery

Thunder resolves its framework root in this order:

1. `THUNDER_FRAMEWORK_ROOT` when it points at a valid Thunder runtime root
2. current working directory ancestors
3. Thunder executable directory ancestors
4. `OPAM_SWITCH_PREFIX/share/thunder` and `OPAM_SWITCH_PREFIX/share/thunder-cloudflare`

This lookup allows the CLI to resolve framework-owned runtime files and templates without forcing every command to be run from the framework repository root.

## `thunder.json`

Thunder apps use `thunder.json` as the app-owned config file for path and layout settings.

Its current shape is:

```json
{
  "app_module": "My_app.Routes",
  "worker_entry_path": "worker/entry.ml",
  "compiled_runtime_path": "dist/worker/thunder_runtime.mjs",
  "wrangler_template_path": "wrangler.toml",
  "deploy_dir": "deploy"
}
```

When present, Thunder CLI reads this file and uses it to override default app-relative paths.

## Framework Files In Generated Apps

Generated apps include a framework-owned path at:

- `vendor/thunder-framework`

Thunder uses that path so generated apps can resolve framework runtime files, scaffolding assets, and CLI-owned deploy/runtime modules during local builds and deploys.

That means a generated app contains two categories of files:

- app-owned files such as `app/routes.ml`, `worker/entry.ml`, and `wrangler.toml`
- framework-owned files made available through `vendor/thunder-framework`

## Why This Matters

Thunder's CLI needs to resolve three kinds of paths correctly:

- app-owned source paths
- framework-owned runtime and template paths
- generated deploy output paths

Those path rules affect:

- `thunder new`
- `thunder init`
- manifest-driven staging
- preview publishing
- production deploys

## Installer Layout

The installer-backed path uses these locations:

- `~/.local/bin/thunder`
- `~/.local/share/thunder/versions/<version>/`
- `~/.local/share/thunder/current`

Thunder's CLI and generated apps use framework-root discovery and `thunder.json` so the same commands can work across both framework-repo and installed-framework setups.
