Current active phase: complete - JS/Wasm dual-target roadmap implemented for current release scope

# Thunder JS Target Plan

## Goal

Add first-class compile target selection for Thunder apps so users can build to JavaScript or Wasm, with:

- `--target js|wasm` as the CLI/build flag shape
- `js` as the default when no target is specified
- `wasm` remaining fully supported
- the Worker host and app programming model staying consistent across targets

## Non-goals for this plan

- add a new runtime platform beyond Cloudflare Workers
- change Thunder's request/response/router programming model
- redesign the JSON ABI contract unless required for target selection
- remove Wasm support
- add streaming, multipart, or WebSocket support
- promise identical artifact shapes for JS and Wasm when that adds unnecessary complexity

## Product principles

1. Target selection should be explicit in the system, even when `js` is the default.
2. Existing and new apps should resolve a missing target to `js`.
3. Generated apps should default to the most common path: `js`.
4. Runtime and deploy logic should stay framework-owned.
5. The manifest should describe the selected runtime truthfully rather than forcing Wasm-shaped fields onto JS builds.
6. Tests and docs must validate both supported targets.

## Proposed end state

Users can build Thunder apps like this:

```bash
dune build
dune build @worker-build
dune build @worker-build -- --target wasm
```

Or through Thunder-owned config:

```json
{
  "compile_target": "js"
}
```

Target behavior:

- if no target is configured or passed, Thunder uses `js`
- if `--target wasm` is selected, Thunder builds and stages the current Wasm-backed runtime path
- if `--target js` is selected, Thunder builds and stages a JS runtime path with no Wasm asset generation
- preview publish and production deploy operate on whichever target the manifest describes
- generated apps scaffold with `js` as the default compile target

## Required architecture shift

Thunder currently assumes a single Wasm-backed compiled runtime path in:

- `packages/thunder_cli/scaffold.ml`
- `packages/thunder_cli/project_layout.ml`
- `packages/thunder_cli/thunder_config.ml`
- `packages/thunder_cli/deploy_manifest.ml`
- `packages/thunder_cli/deploy_layout.ml`
- `worker_runtime/app_abi.mjs`
- `worker_runtime/compiled_runtime_backend.mjs`
- `worker_runtime/compiled_runtime_bootstrap.mjs`

This plan introduces a first-class runtime target model that flows through:

- config
- scaffolded app build rules
- manifest generation
- runtime backend selection
- deploy staging
- docs and tests

---

# Phase J1 - Target model and compatibility contract

## Goal

Define the target-selection model and make `js` the universal default when target is omitted.

## Tasks

### J1.1 Define the target enum

Add a single target enum with these supported values:

- `js`
- `wasm`

Acceptance:

- the plan and implementation consistently use `js|wasm`
- no boolean `use_js` or `is_wasm` config shape becomes the public contract

### J1.2 Define config precedence

Freeze the precedence order for target resolution:

1. explicit CLI `--target`
2. app `thunder.json` `compile_target`
3. framework default `js`

Acceptance:

- precedence is documented
- implementation can follow it without ambiguity

### J1.3 Define omitted-target behavior

When `compile_target` and `--target` are both absent, resolve to `js`.

Acceptance:

- omitted target behavior is documented once and used consistently
- no migration mode or legacy fallback path is required

### J1.4 Define public CLI contract

Introduce:

- `--target js`
- `--target wasm`

Plan to retire or internally translate any Wasm-specific CLI naming such as `--wasm` where appropriate.

Acceptance:

- user-facing CLI shape is target-based
- help text and docs describe the new contract

### J1.5 Add checkpoint note

## Checkpoint: J1 complete

Completed:

- defined `js|wasm` as the only supported compile targets
- froze CLI/config/default precedence
- established omitted target resolution to `js`
- established `--target` as the primary user-facing contract
- confirmed no migration path or legacy omitted-target fallback is needed

Verified:

- plan updated
- target-selection contract is unambiguous across CLI, config, and generated apps

Next:

- update config/layout/scaffold plumbing to carry the selected target end to end

---

# Phase J2 - CLI, config, and layout plumbing

## Goal

Thread target selection through Thunder CLI and app config without changing runtime behavior yet.

## Tasks

### J2.1 Extend `thunder.json`

Add:

- `compile_target`

Keep existing fields working during migration.

Acceptance:

- config parser accepts `compile_target`
- invalid target values fail clearly
- missing target remains valid and resolves to `js`

### J2.2 Generalize `Project_layout`

Refactor `packages/thunder_cli/project_layout.ml` so layout derives from target-aware inputs instead of a single Wasm-assumed artifact path.

Need:

- target-aware runtime artifact path handling
- target-aware asset directory handling
- stable defaults for generated apps

Acceptance:

- layout can represent both JS and Wasm builds
- layout no longer assumes `thunder_runtime.assets` always exists

### J2.3 Update CLI argument parsing

Replace or supersede Wasm-specific CLI assumptions in `packages/thunder_cli/main.ml`.

Need:

- parse `--target`
- carry the resolved target into preview/deploy flows
- preserve clear errors for unsupported values

Acceptance:

- preview and deploy commands both accept `--target`
- default target is `js` when nothing is passed

### J2.4 Update artifact selection helpers

Refactor artifact collection so optional target-specific artifacts are handled intentionally.

Acceptance:

- JS builds do not require Wasm asset directories
- Wasm builds still include the current asset set

### J2.5 Add unit tests for config and layout resolution

Acceptance:

- tests cover config parsing
- tests cover CLI/config/default precedence
- tests cover both `js` and `wasm`

### J2.6 Add checkpoint note

## Checkpoint: J2 complete

Completed:

- added target-aware config parsing
- threaded target selection through CLI and layout resolution
- generalized artifact selection for both runtime targets

Verified:

- `tests/cli_tests.ml` now covers `js` and `wasm` target resolution
- `dune build packages/thunder_cli/main.exe tests/cli_tests.exe`
- `dune exec ./packages/thunder_cli/main.exe -- preview-publish --target lua`

Next:

- make manifest generation and deploy staging target-aware

---

# Phase J3 - Manifest and staging generalization

## Goal

Make the deploy manifest describe either runtime target cleanly and let staging copy only what that target needs.

## Tasks

### J3.1 Add manifest runtime kind

Extend the manifest with an explicit runtime discriminator, for example:

- `runtime_kind: "js"`
- `runtime_kind: "wasm"`

Acceptance:

- manifest explicitly identifies the selected runtime kind
- downstream logic does not infer target indirectly from file presence

### J3.2 Make Wasm-specific manifest fields optional

Fields such as these should be optional or target-scoped:

- `generated_wasm_assets`
- `bootstrap_module`
- `assets_dir`

Acceptance:

- JS manifests validate without Wasm-only fields
- Wasm manifests still carry the fields they need

### J3.3 Update deploy manifest parsing

Refactor `packages/thunder_cli/deploy_manifest.ml` to parse target-aware manifests safely.

Acceptance:

- parse errors clearly describe missing required fields by target
- JS and Wasm manifest parsing are both covered by tests

### J3.4 Update deploy staging

Refactor `packages/thunder_cli/deploy_layout.ml` to stage files conditionally based on manifest target.

Acceptance:

- JS staging copies only required JS runtime files
- Wasm staging preserves current runtime/bootstrap/assets behavior
- missing-file errors remain actionable

### J3.5 Update artifact hashing behavior

Ensure artifact hashing tracks the manifest-declared target shape correctly.

Acceptance:

- changing target changes the effective artifact set
- preview caching remains correct for both targets

### J3.6 Add checkpoint note

## Checkpoint: J3 complete

Completed:

- introduced explicit runtime kind in the manifest
- made manifest parsing target-aware
- staged deploy trees from target-specific manifest inputs
- aligned artifact hashing with target-specific artifact sets

Verified:

- `tests/cli_tests.ml` covers JS and Wasm manifest parsing
- `tests/cli_tests.ml` covers JS deploy staging and unchanged-preview hashing
- `env -u CLOUDFLARE_API_TOKEN dune exec ./tests/cli_tests.exe`

Next:

- implement runtime backend selection for JS and Wasm

---

# Phase J4 - Runtime backend split

## Goal

Support both compiled runtime backends behind the existing Thunder Worker host.

## Tasks

### J4.1 Split backend resolution in `app_abi`

Refactor `worker_runtime/app_abi.mjs` to resolve:

- compiled JS backend
- compiled Wasm backend
- existing test shim override

Acceptance:

- backend selection is driven by manifest/runtime target, not hardcoded Wasm default
- init result reports the actual backend kind used

### J4.2 Add JS compiled runtime backend

Create a JS backend module that:

- imports the compiled JS runtime
- waits for `globalThis.thunder_handle_json`
- invokes the exported handler without Wasm asset bootstrapping

Acceptance:

- JS backend does not depend on Wasm asset shims
- JS backend reuses the existing ABI request/response flow

### J4.3 Preserve Wasm compiled runtime backend

Keep the current Wasm backend path working, including:

- bootstrap behavior
- bundled asset lookup
- initialization errors

Acceptance:

- Wasm runtime behavior remains unchanged aside from target-aware dispatch

### J4.4 Keep Worker host stable

Minimize changes in `worker_runtime/index.mjs` so it remains the Cloudflare-facing entrypoint for both targets.

Acceptance:

- request encoding and response decoding stay shared
- target-specific logic stays in ABI/backend layers

### J4.5 Expand runtime tests

Update `worker_runtime/index_test.mjs` to validate:

- JS backend selection
- Wasm backend selection
- shim override precedence
- target-specific init failure behavior

Acceptance:

- runtime tests cover both supported backends
- no test assumes Wasm is the only production backend

### J4.6 Add checkpoint note

## Checkpoint: J4 complete

Completed:

- split runtime backend resolution by target
- added a JS compiled runtime backend
- preserved the current Wasm backend path
- kept the Worker host stable across targets

Verified:

- `node --test worker_runtime/index_test.mjs`
- backend selection, JS backend invocation, and Wasm init tests pass for both targets

Next:

- update scaffolded builds to emit JS by default and Wasm on request

---

# Phase J5 - Build graph and scaffold updates

## Goal

Teach Thunder and generated apps to build the selected runtime target, with JS as the default.

## Tasks

### J5.1 Choose and freeze JS compilation strategy

Decide the concrete JS build mechanism for `worker/entry.ml`, likely one of:

- Dune JS mode
- explicit `js_of_ocaml` compilation from bytecode

Acceptance:

- one build strategy is chosen and documented
- the strategy works in both the framework repo and generated apps

### J5.2 Update root build graph

Refactor repo-root `dune` rules so `@worker-build` can build the selected target.

Acceptance:

- JS build emits the expected compiled runtime module
- Wasm build still emits current runtime module plus Wasm assets

### J5.3 Update generated app scaffold

Refactor `packages/thunder_cli/scaffold.ml` templates so new apps:

- default to `compile_target = "js"`
- expose a target-aware build path
- generate a target-aware manifest

Acceptance:

- `thunder new` scaffolds apps with JS as the default path
- scaffolded apps can still build Wasm when requested

### J5.4 Keep output locations intentional

Prefer a stable output path such as `dist/worker/thunder_runtime.mjs` across both targets where practical.

Acceptance:

- downstream runtime/deploy code does not need unnecessary path branching
- target differences live in manifest/runtime metadata, not arbitrary filenames

### J5.5 Update generated app tests

Expand scaffold tests and fixture verification to assert:

- `compile_target = "js"` in scaffolded config
- target-aware build rules exist
- scaffolded runtime assets differ appropriately by target

Acceptance:

- generated app fixture tests cover the default JS path
- fixture tests still cover Wasm support explicitly

### J5.6 Add checkpoint note

## Checkpoint: J5 complete

Completed:

- froze the JS compilation strategy
- made the root and generated-app build graphs target-aware
- changed scaffold defaults to `js`
- preserved Wasm as an explicit supported build target

Verified:

- `dune build @worker-build`
- `THUNDER_COMPILE_TARGET=wasm dune build @worker-build`
- `dune build tests/cli_tests.exe && env -u CLOUDFLARE_API_TOKEN dune exec ./tests/cli_tests.exe`

Next:

- update docs, smoke flows, and release validation for dual-target support

---

# Phase J6 - Docs, smoke coverage, and release hardening

## Goal

Document the new target model and ensure validation paths cover both supported targets.

## Tasks

### J6.1 Update top-level docs

Update:

- `README.md`
- `KICKSTART.md`
- `docs/architecture.md`
- `docs/deployment.md`
- `docs/supported_features.md`

Need:

- `js` is the default compile target
- `wasm` remains supported
- examples show `--target wasm` when relevant

Acceptance:

- docs no longer describe Wasm as the only supported compiled runtime path
- docs explain target selection clearly

### J6.2 Update runtime architecture docs

Revise architecture descriptions that currently assume a single Wasm production backend.

Acceptance:

- architecture docs describe shared host + target-specific compiled backend model
- manifest/runtime-kind role is documented

### J6.3 Update smoke and CI validation

Expand smoke coverage in:

- `scripts/preview_smoke.sh`
- CI workflows
- release checklist docs

Acceptance:

- at least one validation path covers JS
- at least one validation path covers Wasm
- release docs stop referring to a single compiled-runtime path only

### J6.4 Add target-selection usage notes

Document how apps should rely on the new default and when to choose Wasm explicitly.

Acceptance:

- docs explain that omitted target resolves to `js`
- docs explain how to request Wasm intentionally

### J6.5 Add final checkpoint note

## Checkpoint: J6 complete

Completed:

- updated docs for dual-target support
- validated smoke and CI flows for both runtime targets
- documented default target behavior and explicit Wasm selection

Verified:

- docs now describe JS as the default target and Wasm as explicit
- `python3 -m py_compile scripts/render_selected_runtime.py`
- `bash -n scripts/preview_smoke.sh`
- `dune build @worker-build`
- `THUNDER_COMPILE_TARGET=wasm dune build @worker-build`

Next:

- monitor whether the Wasm path should remain equally prominent or become an advanced option later

---

# Cross-cutting acceptance criteria

Thunder JS target support is done only when:

- `--target js|wasm` is the public target-selection interface
- missing target resolves to `js`
- generated apps default to `compile_target = "js"`
- Wasm builds still succeed intentionally
- manifest parsing and deploy staging work for both targets
- runtime tests cover both target backends
- scaffold tests cover the new default JS path
- docs describe dual-target support accurately

# Open questions

## Q1. JS compiler wiring choice

The implementation should decide whether to standardize on:

- Dune JS mode
- explicit `js_of_ocaml` compilation from bytecode

Recommended direction:

- choose the simpler path that produces a deterministic module artifact compatible with the current Worker host expectations

## Q2. Manifest versioning policy

If the manifest shape changes materially, decide whether to:

- increment `abi_version`
- add a separate manifest version field
- evolve manifest parsing compatibly without version bumps

Recommended direction:

- keep ABI version scoped to request/response contract
- version the manifest format separately only if parsing compatibility becomes awkward
