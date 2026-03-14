Current active phase: complete - frameworkification roadmap implemented for current release scope

# Thunder Framework Plan

## Goal

Turn Thunder from a framework repo that doubles as the app into a true framework product:

- users install Thunder
- users run `thunder new my-app`
- a new app repo is scaffolded automatically
- app code lives in app-owned directories (`app/`, `bin/`, `worker/`, `test/`)
- Thunder runtime/deploy internals stay in framework-owned libraries and CLI
- generated apps keep Thunder's key workflow:
  - `dune build` builds Worker artifacts
  - preview upload runs automatically only when the staged artifact hash changes
  - production deploy remains explicit

## Non-goals for this plan

- decide the final framework distribution channel now
- implement granular per-section artifact uploads
- add new runtime targets beyond Cloudflare Workers
- expand beyond buffered request/response runtime semantics

## Product principles

1. Users should not edit Thunder internals to build an app.
2. Generated apps should feel like first-class Thunder projects, not copied examples.
3. `dune build` auto-preview-on-change remains a core feature.
4. Runtime/deploy internals stay framework-owned and versioned.
5. Generated apps should remain inspectable and debuggable.
6. Breaking changes are acceptable while Thunder is pre-release, but the generated app shape should still be intentional and stable once introduced.

## Proposed end state

A typical user flow:

```bash
<thunder install step>
thunder new my-app
cd my-app
npm install
dune build
```

Generated app shape:

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

Framework-owned internals:

- runtime JS files
- ABI shim
- compiled runtime backend
- manifest generation
- deploy staging
- preview/deploy orchestration
- app scaffolding templates

Generated app-owned files:

- routes
- handlers
- middleware
- app tests
- app README
- app `wrangler.toml`
- app `package.json`
- app-specific Thunder config

## Required architecture shift

Thunder needs a framework-owned app export API so generated apps do not reimplement runtime glue.

Target shape:

```ocaml
let app = My_app.Routes.app
let () = Thunder_cloudflare.Entry.export app
```

This replaces the current framework-repo pattern where app behavior is defined directly inside framework internals.

---

# Phase F1 - Framework/app boundary

## Goal

Define and enforce the boundary between Thunder framework internals and user app code.

## Tasks

### F1.1 Define app-owned vs framework-owned files

Document which files belong to:

- the framework repo
- generated apps
- internal runtime packaging
- user-editable app source

Acceptance:

- boundary is written down in docs/plan
- no ambiguity remains about where a user writes app code

### F1.2 Define generated app directory layout

Choose and freeze the initial app skeleton layout.

Need:

- app source location
- Worker entry location
- test location
- app config location

Acceptance:

- layout is documented
- layout is used consistently in later phases

### F1.3 Define framework entry/export API

Add the planned app entry contract to the roadmap.

Need:

- generated app should pass a Thunder handler/app to framework-owned Worker export code
- user should not own ABI/runtime glue

Acceptance:

- entry/export API shape is documented
- later phases can implement against it without redesign

### F1.4 Mark current repo-root app model as transitional

Document that the current root app setup is a temporary dogfood/dev shape, not the long-term user story.

Acceptance:

- top-level docs stop implying the framework repo is the intended app authoring model

### F1.5 Add checkpoint note

Acceptance:

- checkpoint added after boundary decisions are complete

## Checkpoint: F1 complete
Completed:
- documented the framework/app boundary in `docs/framework_boundary.md`
- froze the initial generated app layout around `app/` and `worker/entry.ml`
- documented the planned framework-owned export API direction
- marked the current repo-root app model as transitional in top-level docs

Verified:
- `PLAN2.md` created with phased framework roadmap
- docs updated (`README.md`, `KICKSTART.md`, `docs/architecture.md`, `docs/framework_boundary.md`)

Next:
- implement the framework-owned export API in `thunder_worker`
- refactor the current dogfood app to use it

---

# Phase F2 - Framework-owned app export API

## Goal

Replace the current "framework repo contains the app" wiring with a framework-owned export path.

## Tasks

### F2.1 Introduce `Thunder_cloudflare.Entry.export`

Need:

- framework-owned function for exposing an app to Worker runtime
- app authors only pass their app/router/handler

Acceptance:

- export path exists in public API
- current dogfood app can compile through it

### F2.2 Refactor current runtime wiring to use export API

Need:

- remove direct dependence on repo-local app wiring for the supported path
- preserve current runtime behavior

Acceptance:

- worker build still succeeds
- preview smoke still succeeds

### F2.3 Create a minimal framework fixture app using new API

Need:

- one internal fixture app proving the contract works outside the current hardcoded shape

Acceptance:

- fixture app builds and runs through the export API

### F2.4 Update docs around app entrypoint

Acceptance:

- docs show framework-owned export flow, not raw internal runtime wiring

### F2.5 Add checkpoint note

Progress note:

- `packages/thunder_worker/entry.ml` and `packages/thunder_worker/entry.mli` now exist as the first implementation of the framework-owned export API, and the current dogfood app is being refactored to call `Entry.export app`.
- the repo-local app routes are also being split into `packages/thunder_worker/dogfood_app.ml` so `wasm_entry.ml` can shrink toward the future generated-app `worker/entry.ml` shape.

## Checkpoint: F2 complete
Completed:
- introduced the framework-owned export API in `packages/thunder_worker/entry.ml` and `packages/thunder_worker/entry.mli`
- refactored the current dogfood app to export through `Entry.export`
- split repo-local routes into `packages/thunder_worker/dogfood_app.ml` so `wasm_entry.ml` now looks like the future generated-app entry wrapper shape

Verified:
- `opam exec -- dune build packages/thunder_worker/wasm_entry.bc`
- `env -u CLOUDFLARE_API_TOKEN opam exec -- dune runtest`
- `opam exec -- dune build @worker-build`

Next:
- begin Phase F3 by isolating current path/layout assumptions inside the CLI and documenting install-context requirements
- prepare runtime/deploy asset lookup for use outside the Thunder monorepo

---

# Phase F3 - Package/install boundary

## Goal

Make Thunder usable outside the monorepo by resolving runtime assets and CLI behavior from an installed framework context.

## Tasks

### F3.1 Decide public package boundaries

Candidates:

- `thunder`
- `thunder-cloudflare`
- `thunder-cli`

Need:

- identify what is public vs internal
- avoid exposing too many low-level packages prematurely

Acceptance:

- package map documented
- later installation/distribution work can target it

### F3.2 Remove repo-root assumptions from runtime asset lookup

Need:

- runtime JS assets
- manifest logic
- staging logic
- CLI template resolution

to work when Thunder is installed rather than cloned

Acceptance:

- runtime/deploy code no longer depends on framework repo-relative paths

### F3.3 Introduce version coordination rules

Need:

- CLI version
- runtime asset version
- ABI version
- generated app template version

must have a clear compatibility story

Acceptance:

- version compatibility policy documented

### F3.4 Create install-context smoke strategy

Acceptance:

- there is a concrete validation path for "framework installed elsewhere, generated app still works"

Progress note:

- current app-relative CLI path assumptions are now being centralized so install-context resolution can replace them incrementally rather than by rewriting every command at once.
- framework-root discovery is now being taught to search environment override, current workspace ancestors, executable ancestors, and likely opam share locations.
- a first `thunder.json` reader is now being introduced so generated apps can declare their own layout explicitly instead of depending purely on hardcoded defaults.

### F3.5 Add checkpoint note

---

# Phase F4 - App scaffolder (`thunder new`)

## Goal

Generate a new Thunder app automatically.

## Tasks

### F4.1 Add `thunder new <name>` command

Need:

- create target directory
- validate name
- refuse unsafe overwrites
- write a complete scaffold

Acceptance:

- command creates a working app tree

Progress note:

- `packages/thunder_cli/scaffold.ml` now creates an initial Thunder app skeleton and `thunder new <project-name>` is wired up as the first scaffolding command.
- the scaffold now includes `bin/main.ml` so generated apps have an app-owned local executable entrypoint in addition to `worker/entry.ml`.
- a fresh generated app layout can now be written and inspected, but `dune build @worker-build` still blocks on the unresolved install story (`thunder.worker` package visibility outside the framework workspace).
- the scaffold now vendors a temporary framework bundle under `vendor/thunder-framework`, which is enough to make `dune build @worker-build` succeed in a fresh generated app.
- a fresh generated app now completes plain `dune build` successfully when `CLOUDFLARE_API_TOKEN` is absent, with preview publish skipping non-fatally as intended.

### F4.2 Add template files

Need scaffold templates for:

- `dune-project`
- app `dune`
- `package.json`
- `wrangler.toml`
- `thunder.json`
- `.gitignore`
- app README
- starter route files
- worker entry file
- smoke test file

Acceptance:

- generated scaffold is internally consistent

### F4.3 Generate starter app

Recommended starter routes:

- `/`
- `/health`

Acceptance:

- generated app gives a usable first deploy target immediately

### F4.4 Add `thunder init`

Need:

- support adding Thunder to an existing directory/repo later

Acceptance:

- init path is designed, even if implemented after `new`

Progress note:

- `thunder init [project-name]` now exists as the first existing-directory scaffolding path and shares template generation with `thunder new`.

### F4.5 Add scaffold tests

Need:

- verify file generation
- verify naming substitutions
- verify produced app layout

Acceptance:

- scaffold output is test-covered

Progress note:

- CLI scaffold tests now cover both `create_project` and `init_project`, including generation of `thunder.json`, `worker/entry.ml`, and `test/dune`.

### F4.6 Add checkpoint note

## Checkpoint: F4 complete
Completed:
- added `thunder new <project-name>` as the first generated-app scaffolding command
- added `thunder init [project-name]` for existing-directory scaffolding
- created the first generated app layout around `app/`, `bin/`, `worker/`, and `test/`
- added `thunder.json` as the generated app config contract for Thunder-owned path/layout assumptions
- made fresh generated apps complete local `dune build @worker-build` and plain `dune build` successfully when preview upload is skipped due to missing credentials
- added scaffold tests covering generated files, route templates, worker entry export wiring, and existing-directory initialization

Verified:
- `opam exec -- dune build packages/thunder_cli/main.exe tests/cli_tests.exe`
- `env -u CLOUDFLARE_API_TOKEN opam exec -- dune runtest`
- generated fresh app with `thunder new` and verified `dune build @worker-build`
- generated fresh app with `thunder new` and verified `env -u CLOUDFLARE_API_TOKEN dune build`

Next:
- begin Phase F5 by validating preview and deploy behavior from generated apps with credentials
- tighten generated-app staging/deploy flow so it no longer depends on the temporary vendored framework bundle long-term

---

# Phase F5 - Generated app build/deploy flow

## Goal

Make generated apps preserve Thunder's signature workflow.

## Tasks

### F5.1 Move build aliases into generated app template

Need generated app to own:

- `@worker-build`
- `@preview-publish`
- `@deploy-prod`
- default alias behavior

Acceptance:

- generated app `dune build` performs build + preview-if-changed

### F5.2 Make generated app preview hashing/staging work end-to-end

Need:

- generated app uses Thunder CLI/runtime assets
- staged deploy tree is produced correctly
- preview metadata is local to generated app

Acceptance:

- generated app preview upload works

Progress note:

- credentialed preview upload has now been validated from a fresh generated app by temporarily targeting an existing Worker; the generated app preview returned the scaffolded `/` and `/health` routes successfully.
- generated app preview metadata now lands correctly at app-root `.thunder/preview.json`.

### F5.3 Keep production deploy explicit

Acceptance:

- generated app deploy still requires explicit confirmation

Progress note:

- generated-app explicit deploy has now been validated against an existing Worker; `CONFIRM_PROD_DEPLOY=1 dune build @deploy-prod` completed successfully and the deployed `/`, `/health`, and missing-route behavior matched the scaffolded app.

### F5.4 Add generated-app preview smoke

Acceptance:

- generated app passes the same smoke path now used by the framework repo

### F5.5 Add checkpoint note

## Checkpoint: F5 complete
Completed:
- generated app templates now own `@worker-build`, `@preview-publish`, `@deploy-prod`, and default `dune build` behavior
- fresh generated apps complete local `dune build @worker-build` and plain `dune build` successfully
- generated app preview upload has been validated with credentials against an existing Worker target
- generated app explicit production deploy has been validated with confirmation guard and real deploy verification against an existing Worker target
- generated app preview metadata now lands at app-root `.thunder/preview.json`

Verified:
- `opam exec -- dune build packages/thunder_cli/main.exe tests/cli_tests.exe`
- `env -u CLOUDFLARE_API_TOKEN opam exec -- dune runtest`
- fresh generated app: `dune build @worker-build`
- fresh generated app: `env -u CLOUDFLARE_API_TOKEN dune build`
- fresh generated app: `THUNDER_FORCE_PREVIEW=1 dune build` against existing Worker target
- fresh generated app: `CONFIRM_PROD_DEPLOY=1 dune build @deploy-prod` against existing Worker target

Next:
- begin Phase F6 by making generated apps the primary documented onboarding and dogfood path
- introduce a stable generated-app fixture path for framework verification

---

# Phase F6 - Dogfood generated apps

## Goal

Prove that generated apps are the primary user path.

## Tasks

### F6.1 Add a generated-app fixture repo shape

Need:

- framework tests run against a generated app fixture, not only the monorepo dogfood app

Acceptance:

- generated fixture becomes the main smoke target

Progress note:

- `scripts/verify_generated_app_fixture.sh` now materializes a fresh generated app and verifies `dune build @worker-build` plus plain `dune build`, giving Thunder a stable generated-app fixture workflow even before a committed fixture repo is frozen.

### F6.2 Run preview/prod verification against generated fixture

Acceptance:

- generated fixture supports build, preview smoke, and explicit deploy

Progress note:

- generated apps now have validated preview and explicit deploy behavior against a real Worker target, and `scripts/verify_generated_app_fixture.sh` covers the stable local build fixture path.

### F6.3 Rewrite top-level onboarding docs around generated apps

Need:

- `README.md`
- `KICKSTART.md`
- deployment docs

to lead with the generated app workflow

Acceptance:

- users are no longer told to clone Thunder to start building an app

Progress note:

- `README.md`, `KICKSTART.md`, and deployment docs now lead with the generated-app workflow and position the framework repo as the dogfood/development path.

### F6.4 Add checkpoint note

## Checkpoint: F6 complete
Completed:
- added `scripts/verify_generated_app_fixture.sh` as the stable generated-app fixture verification path inside the framework repo
- validated generated-app preview and explicit deploy behavior against a real Worker target
- rewrote top-level onboarding so generated apps are now the primary documented user path
- repositioned the framework repo as the contributor/dogfood workspace rather than the main user app workflow

Verified:
- `bash scripts/verify_generated_app_fixture.sh`
- `env -u CLOUDFLARE_API_TOKEN opam exec -- dune runtest`
- generated app preview/deploy validation against an existing Worker target

Next:
- begin F7 by documenting the current release/install story around the working generated-app model
- preserve the current generated-app UX while deferring the final distribution-method decision

---

# Phase F7 - Release-ready framework UX

## Goal

Finalize Thunder as a framework product.

## Tasks

### F7.1 Finalize install story

Need:

- choose distribution path
- document install steps
- verify app generation from fresh environment

Acceptance:

- install + scaffold + build + preview path is documented and works

Progress note:

- generated apps now work end-to-end with the current temporary vendored framework bundle, so F7 can focus on turning that working model into a polished release/install story without changing the app-facing folder organization.
- `docs/release_install_story.md` now captures the preferred initial direction: curl-installed Thunder binary plus a shared installed framework home as the replacement for `vendor/thunder-framework`.
- `scripts/install_thunder.sh` now provides the first concrete implementation of a versioned framework-home install under `~/.local/share/thunder/versions/<version>/` with `current` pointing at the active release.
- the installed-binary + installed-framework-home path has now been verified locally by installing Thunder into temporary bin/home directories, generating a fresh app, and confirming `dune build @worker-build` plus plain `dune build` succeed.

### F7.2 Finalize generated app docs

Need:

- first app guide
- deployment guide
- troubleshooting
- runtime model
- release checklist

Acceptance:

- docs match the generated app reality, not the framework monorepo

### F7.3 Final framework hardening pass

Audit:

- generated app ergonomics
- runtime asset resolution
- preview auto-publish behavior
- explicit prod deploy
- version skew handling
- template drift

Acceptance:

- generated apps are the canonical Thunder workflow
- framework repo is clearly positioned as framework source, not user app template

### F7.4 Add final checkpoint note

## Checkpoint: F7 complete
Completed:
- documented and implemented the first release/install story around a curl-installed `thunder` binary plus a versioned installed framework home
- added `scripts/install_thunder.sh` to install the Thunder binary and framework assets into `~/.local/share/thunder/versions/<version>/` with `current` pointing at the active release
- added `thunder doctor` as a post-install validation step for binary/framework-home/tool discovery
- verified generated apps work through the installed binary flow while keeping the intended app folder organization
- finalized the generated-app-first onboarding/docs direction while preserving the framework repo as the contributor/dogfood workspace

Verified:
- `env -u CLOUDFLARE_API_TOKEN opam exec -- dune runtest`
- `bash scripts/verify_generated_app_fixture.sh`
- installed-binary flow: `scripts/install_thunder.sh`, `thunder doctor`, `thunder new my-app`, generated app `dune build @worker-build`, generated app plain `dune build`

Next:
- treat the generated-app workflow as the canonical Thunder product path
- revisit long-term packaging/distribution choices only if they improve on the current curl-installed binary plus installed framework-home model without regressing the generated-app UX

---

# Cross-cutting risks

- runtime asset resolution outside the monorepo
- version skew between CLI/runtime/ABI/template
- generated app templates drifting from framework behavior
- exposing too many low-level OCaml packages as public API
- keeping `dune build` auto-preview behavior understandable to new users

# Deferred decisions

These decisions are intentionally deferred until the phases are complete enough to make them with real data:

- final framework distribution method
- whether to provide an additional npm-based bootstrap wrapper
- whether to keep all current package names or rename the Cloudflare-facing package/module layout

# Success criteria

Thunder framework-ification is successful when:

- a user can create a new app without cloning the Thunder repo
- user app code lives in app-owned directories, not Thunder internals
- Thunder runtime/deploy internals are framework-owned
- generated apps keep auto-preview-on-changed-build
- production deploy remains explicit
- the generated app path is the primary documented onboarding story
