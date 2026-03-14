# Framework Boundary

This document defines the planned boundary between Thunder framework internals and generated Thunder apps.

Thunder is currently still dogfooding itself from the framework repository, but that is a transitional development shape, not the long-term user model.

## User-owned app code

Generated Thunder apps should own and edit:

- `app/`
  - routes
  - handlers
  - middleware
  - app-specific modules
- `worker/entry.ml`
  - tiny Worker entrypoint that exports the app through Thunder's framework-owned API
- `bin/`
  - optional app-owned executables and local tooling
- `test/`
  - app tests and smoke tests
- `wrangler.toml`
- `package.json`
- `dune-project`
- app `dune`
- `thunder.json`
- app `README.md`

## Framework-owned internals

Thunder should own and version:

- runtime JS files in `worker_runtime/`
- ABI/runtime bridge code
- compiled runtime backend
- staged deploy manifest generation
- preview/deploy orchestration in `thunder_cli`
- scaffolding templates used by `thunder new`

Generated apps should consume these pieces, not edit them directly.

Transitional note:

- the current scaffold temporarily links or copies a framework bundle into `vendor/thunder-framework` so generated apps can build before Thunder's final install/distribution story is chosen
- this is a bridge toward the installable-framework model, not the end state

Current scaffolding status:

- `thunder new <name>` creates the first generated-app layout
- `thunder init [project-name]` writes the same layout into an existing directory
- generated apps now complete local `dune build` successfully when preview upload is skipped due to missing credentials
- generated apps have now validated preview and explicit deploy flow against a real Worker target
- `scripts/verify_generated_app_fixture.sh` is now the stable generated-app smoke path inside the framework repo

## Generated app layout

Planned default layout:

```text
my-app/
  dune-project
  my-app.opam
  dune
  package.json
  wrangler.toml
  thunder.json
  .gitignore
  README.md
  app/
    routes.ml
    routes.mli
    middleware.ml
    middleware.mli
  bin/
    main.ml
  worker/
    entry.ml
  test/
    smoke_test.ml
```

## Planned export API

Generated apps should use a framework-owned entry/export API along these lines:

```ocaml
let app = My_app.Routes.app
let () = Thunder_cloudflare.Entry.export app
```

This keeps user code focused on the app itself while Thunder owns the Worker runtime boundary.

Implementation status:

- the first framework-owned export helper is now being introduced in `packages/thunder_worker/entry.ml`
- the current dogfood app in `packages/thunder_worker/wasm_entry.ml` is moving to that API first
- the repo-local app routes are being isolated in `packages/thunder_worker/dogfood_app.ml` so the entry file itself can stay tiny and framework-shaped
- install-context assumptions are being documented in `docs/install_context.md` and centralized in CLI layout helpers as the first Phase F3 slice
- the first generated-app scaffolding slice now exists in `packages/thunder_cli/scaffold.ml`, targeting the planned `app/` and `worker/entry.ml` layout

## Transitional note

Today the framework repo still deploys the app defined in `packages/thunder_worker/wasm_entry.ml`.

That file should be treated as a temporary dogfood app while Thunder moves toward generated first-class apps.
