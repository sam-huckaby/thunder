# Framework Boundary

This document defines the boundary between user-owned Thunder app code and framework-owned Thunder internals.

Thunder apps should focus on routes, middleware, handlers, and app-specific modules. Thunder itself owns the Worker runtime boundary, runtime packaging, and deploy orchestration.

## User-Owned App Code

Generated Thunder apps own and edit:

- `app/`
  - routes
  - handlers
  - middleware
  - app-specific modules
- `worker/entry.ml`
  - the small Worker entrypoint that exports the app through Thunder's framework-owned API
- `bin/`
  - optional app-owned executables and local tooling
- `test/`
  - app tests and smoke tests
- `wrangler.toml`
- `package.json`
- `dune-project`
- app `dune` files
- `thunder.json`
- app `README.md`

## Framework-Owned Internals

Thunder owns and versions:

- runtime JavaScript files in `worker_runtime/`
- the JSON ABI bridge between the Worker host and compiled app runtime
- the compiled runtime backend and bootstrap modules
- deploy manifest generation
- preview and production deploy orchestration in `thunder_cli`
- scaffolding templates used by `thunder new` and `thunder init`

Generated apps consume these pieces. They are framework internals, not normal app editing surfaces.

## Generated App Layout

The generated app layout is:

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

## Export API

Generated apps export their app through a framework-owned Worker entry helper.

The current shape is:

```ocaml
let app = My_app.Routes.app |> My_app.Middleware.apply

let () = Entry.export app
```

This keeps app code focused on application behavior while Thunder owns the Worker runtime registration and ABI boundary.

## Repo Layout Versus App Layout

The framework repository includes a repo-local app entry at `packages/thunder_worker/wasm_entry.ml` for framework development and verification.

That repo-local entry uses the same architecture as a generated app:

- an app handler graph in OCaml
- a tiny export wrapper
- the Thunder Worker runtime host
- manifest-driven staging and deploy packaging

Generated apps are the public product shape. The framework repository is the source tree that produces the runtime, CLI, and templates those apps consume.
