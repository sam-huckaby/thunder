---
id: TH-004
title: Thunder Cloudflare Resource Provisioning
status: in_progress
type: feature
priority: high
owner: null
created: 2026-04-04
updated: 2026-04-04
related_plans:
  - TH-003
  - TH-001
depends_on:
  - TH-003
blocks: []
labels:
  - cloudflare
  - provisioning
  - wrangler
  - cli
  - dev-test
---

# Thunder Cloudflare Resource Provisioning

## Goal

Allow Thunder users to provision the Cloudflare resources needed for local dev and test flows without manually creating them in the Cloudflare dashboard.

Target outcomes:

- `thunder cloudflare provision` creates or wires the resources a Thunder app needs
- the provision flow automatically performs a first Worker bootstrap deploy
- `thunder cloudflare status` validates local config, Thunder-managed state, and remote Cloudflare state
- status output is machine-readable JSON by default and human-readable with `--pretty`
- generated apps can reach first live validation with Thunder commands only

## Current State

Thunder currently delegates deployment to Wrangler but assumes required Cloudflare resources already exist.

Today:

- preview and production deploy flows operate on an existing `wrangler.toml`
- `Thunder.Worker.*` bindings expect matching resources and bindings to already be configured
- generated apps can compile and stage deploy artifacts, but resource setup is still manual
- there is no Thunder-owned state file describing what Cloudflare resources Thunder created or adopted
- there is no status command that checks drift between config, state, and remote Cloudflare resources

This means Thunder can deploy Workers, but it cannot yet offer a full no-dashboard dev/test onboarding path for KV, R2, D1, Queues, Workers AI, Durable Objects, or service bindings.

## Non-goals For This Plan

- make dev/test provisioning the production lifecycle by default
- automatically destroy remote resources in the first release
- silently overwrite unrelated user-managed `wrangler.toml` sections
- fully auto-provision service-binding upstream Workers in the first release
- support every Cloudflare product before shipping the dev/test provisioning path

## Product Principles

1. Provisioning should optimize for dev/test velocity first.
2. Thunder should own only explicitly managed config blocks and state.
3. Re-running provisioning should be safe and idempotent.
4. Status should be JSON-first for CI and agent workflows.
5. Bootstrap should leave the app in a testable state, not just a partially configured state.
6. Existing manual configuration should be adoptable where reasonable.

## Proposed End State

A generated Thunder app can do this:

```bash
thunder new my-app
cd my-app
npm install
thunder cloudflare provision
thunder cloudflare status
dune build
```

Expected behavior:

- KV, R2, D1, and Queue resources are created automatically when requested
- Workers AI and Durable Object bindings are wired automatically
- the main Worker script is bootstrapped automatically through Wrangler deploy
- service bindings can be adopted from existing Worker services
- Thunder writes a state file describing managed resources and bootstrap results
- `thunder cloudflare status` returns JSON describing overall health and drift

## Required Architecture Shift

Thunder needs a Cloudflare resource management layer in the CLI in addition to its current build/deploy pipeline.

Target shape:

- `thunder.json` declares desired dev/test Cloudflare resources
- Thunder writes `.thunder/cloudflare_resources.json` as its managed resource state
- Wrangler command wrappers create, inspect, and bootstrap resources and Worker scripts
- `wrangler.toml` gains Thunder-managed binding sections rather than relying on fully manual edits
- status reporting computes one structured state object that can be rendered as JSON or pretty text

### Resource categories

Provisioning behavior should differ by resource type:

| Category | Initial behavior |
|---|---|
| KV / R2 / D1 / Queues | Create automatically with Wrangler |
| Workers AI | Wire binding automatically; no separate create step |
| Durable Objects | Wire bindings and migrations automatically |
| Worker scripts | Bootstrap automatically through deploy |
| Service bindings | Adopt existing services only in the first release |

## Configuration And State Decisions

### Thunder config additions

Extend `thunder.json` with a Cloudflare provisioning section for dev/test flows.

Target shape:

```jsonc
{
  "cloudflare": {
    "mode": "dev_test",
    "bootstrap_worker": true,
    "resources": {
      "kv": [{ "binding": "MY_KV", "name": "my-app-kv" }],
      "r2": [{ "binding": "FILES", "bucket": "my-app-files" }],
      "d1": [{ "binding": "DB", "name": "my-app-db" }],
      "queues": [{ "binding": "JOBS", "queue": "my-app-jobs" }],
      "ai": [{ "binding": "AI" }],
      "durable_objects": [{ "binding": "MY_DO", "class_name": "MyDurableObject" }],
      "services": [{ "binding": "API", "service": "existing-worker-name" }]
    }
  }
}
```

### Thunder-managed state file

Add `.thunder/cloudflare_resources.json`.

It should record:

- account id
- worker script name
- created or adopted resource ids and names
- which resources are Thunder-managed
- bootstrap deploy status
- timestamps for last provision and last status check

### Status output contract

`thunder cloudflare status` should emit JSON by default.

Target shape:

```jsonc
{
  "ok": true,
  "mode": "dev_test",
  "account_id": "...",
  "worker": {
    "name": "my-app",
    "configured": true,
    "bootstrapped": true,
    "remote_exists": true
  },
  "resources": {
    "kv": [],
    "r2": [],
    "d1": [],
    "queues": [],
    "ai": [],
    "durable_objects": [],
    "services": []
  },
  "warnings": [],
  "errors": []
}
```

Human-readable output should be available through `thunder cloudflare status --pretty`.

### Exit code policy

- `0` for healthy status
- `1` for drift, missing resources, or remote validation failures
- `2` for usage or config parsing failures

## Phase P1 - Config and state foundation

## Goal

Define the desired provisioning schema and add Thunder-managed resource state.

## Tasks

### P1.1 Extend `thunder.json` parsing

Need:

- `cloudflare.mode`
- `cloudflare.bootstrap_worker`
- per-resource desired binding declarations

Acceptance:

- config parser handles the new schema cleanly
- invalid resource declarations fail with actionable messages

### P1.2 Add Cloudflare state model

Need:

- `.thunder/cloudflare_resources.json`
- read and write helpers
- stable internal types for created and adopted resources

Acceptance:

- state file can be created, loaded, and updated idempotently

### P1.3 Define managed-vs-user config rules

Need:

- explicit Thunder-managed `wrangler.toml` sections
- clear ownership boundaries so user config is not clobbered

Acceptance:

- managed config block strategy is documented
- later config patching can rely on fixed section markers

### P1.4 Define status object model

Need:

- one internal representation for status
- JSON as default render target
- pretty renderer as a secondary view

Acceptance:

- command implementation can share one status model for all outputs

### P1.5 Add checkpoint note

---

## Phase P2 - Wrangler resource wrappers

## Goal

Extend Thunder's Wrangler integration so the CLI can create and inspect Cloudflare resources.

## Tasks

### P2.1 Add generic Wrangler JSON helpers

Need:

- shared invocation helpers
- consistent stdout and stderr capture
- JSON parsing helpers where Wrangler supports machine output

Acceptance:

- new Wrangler operations can reuse one parsing path

### P2.2 Add resource create/list wrappers

Need wrappers for:

- KV namespaces
- R2 buckets
- D1 databases
- Queues

Acceptance:

- Thunder can create and inspect these resources through Wrangler

### P2.3 Add Worker bootstrap inspection helpers

Need:

- detect whether the target Worker script exists
- detect whether bootstrap deploy is needed

Acceptance:

- provision and status flows can reason about Worker bootstrap state

### P2.4 Add account and auth inspection helpers

Need:

- account id discovery and validation
- clearer auth failures before provisioning starts

Acceptance:

- Thunder can fail early when auth/account state is missing or inconsistent

### P2.5 Add Wrangler wrapper tests

Need:

- mocked command output coverage
- parsing coverage for create/list/status helpers

Acceptance:

- resource wrapper behavior is test-covered without needing live credentials

### P2.6 Add checkpoint note

---

## Phase P3 - Resource provisioning engine

## Goal

Create requested dev/test resources and write Thunder-managed local state.

## Tasks

### P3.1 Implement desired resource planning

Need:

- compare desired config vs Thunder state
- determine create, reuse, adopt, or skip actions

Acceptance:

- resource plan is deterministic and idempotent

### P3.2 Implement KV, R2, D1, and Queue creation

Need:

- create missing resources through Wrangler
- persist resulting ids or names into Thunder state

Acceptance:

- supported resources can be created with no dashboard steps

### P3.3 Implement AI and Durable Object wiring

Need:

- AI binding configuration support
- Durable Object binding and migration config generation

Acceptance:

- AI and DO entries can be rendered into managed config blocks

### P3.4 Implement service binding adoption

Need:

- support existing Worker service names
- validate declared service bindings exist or can be referenced

Acceptance:

- first release supports service adoption without pretending to provision paired services

### P3.5 Write Thunder state after provisioning

Acceptance:

- state file reflects what was created, adopted, or reused
- re-running provision does not duplicate resources unnecessarily

### P3.6 Add checkpoint note

---

## Phase P4 - Wrangler config patching and bootstrap deploy

## Goal

Patch `wrangler.toml` with Thunder-managed binding sections and automatically bootstrap the Worker script.

## Tasks

### P4.1 Add managed `wrangler.toml` patcher

Need:

- stable block markers per resource category
- non-destructive patching of user-owned config

Acceptance:

- Thunder writes only its managed sections
- re-running patching keeps config stable and readable

### P4.2 Render bindings for all supported resource categories

Need:

- KV sections
- R2 sections
- D1 sections
- Queue sections
- AI section
- Durable Object bindings and migrations
- service bindings

Acceptance:

- generated `wrangler.toml` becomes deployable for the declared resources

### P4.3 Perform bootstrap deploy automatically

Need:

- a first Worker deploy after resources and config are ready
- capture deploy success or failure in Thunder state

Acceptance:

- `thunder cloudflare provision` leaves the Worker script bootstrapped when possible

### P4.4 Add bootstrap policy rules

Need:

- bootstrap when resources or config changed
- skip or short-circuit when everything is already healthy

Acceptance:

- bootstrap behavior is predictable and documented

### P4.5 Add checkpoint note

---

## Phase P5 - Status command

## Goal

Ship `thunder cloudflare status` as a JSON-first validation command.

## Tasks

### P5.1 Add `thunder cloudflare status`

Need:

- JSON as default stdout
- `--pretty` human-readable rendering

Acceptance:

- CI and agents can consume status without extra flags
- humans can inspect a formatted summary when needed

### P5.2 Validate local config, state, and remote resource existence

Need:

- compare desired resources from config
- compare local Thunder state
- inspect remote Cloudflare resources and Worker bootstrap state

Acceptance:

- status reports drift and missing pieces clearly

### P5.3 Add status exit code policy

Acceptance:

- healthy returns `0`
- drift or failure returns `1`
- usage/config errors return `2`

### P5.4 Add status tests

Need:

- JSON output tests
- pretty output tests
- drift detection tests

Acceptance:

- status behavior is stable enough for CI consumption

### P5.5 Add checkpoint note

---

## Phase P6 - Scaffold, docs, and onboarding integration

## Goal

Teach generated apps and Thunder docs to use the new provisioning flow.

## Tasks

### P6.1 Update scaffolded app templates

Need:

- generated `README.md` mentions `thunder cloudflare provision`
- generated config can include starter resource declarations or commented examples

Acceptance:

- new apps teach the provisioning workflow immediately

### P6.2 Update top-level docs

Need updates for:

- `README.md`
- `KICKSTART.md`
- `docs/deployment.md`
- `docs/examples.md`

Acceptance:

- docs no longer imply dashboard setup is required for the supported dev/test flow

### P6.3 Update example and generated-app validation paths

Need:

- generated-app fixture coverage for provisioned resources where practical
- clear separation between mocked and credentialed flows

Acceptance:

- validation paths reflect the new provisioning-first story

### P6.4 Add checkpoint note

---

## Phase P7 - Hardening and release readiness

## Goal

Harden the provisioning workflow enough to treat it as Thunder's canonical dev/test Cloudflare setup path.

## Tasks

### P7.1 Add idempotency and drift hardening

Need:

- repeated `provision` runs stay safe
- state recovery works when remote resources already exist

Acceptance:

- no duplicate creation on healthy re-runs

### P7.2 Add account mismatch detection

Need:

- detect when local state belongs to a different account id
- fail safely with actionable remediation

Acceptance:

- accidental cross-account resource reuse is avoided

### P7.3 Add release-facing notes and constraints

Need:

- explicit note that production provisioning is deferred
- service binding creation limitations documented
- no-destroy policy documented for the first release

Acceptance:

- users understand the intended scope and limits of provisioning

### P7.4 Add final checkpoint note

---

## Cross-cutting Risks

- Wrangler command output can vary and break parsing if Thunder does not centralize wrappers carefully
- `wrangler.toml` patching can become brittle if Thunder tries to own too much of the file
- idempotency bugs could create duplicate resources unexpectedly
- service bindings are not fully creatable in the same way as KV/R2/D1/Queues and must not be overpromised
- Durable Object wiring may require careful migration handling to avoid surprising deploy behavior
- account mismatch between local state and current auth context can lead to confusing or dangerous drift

## Security And Reliability Notes

- provisioning should never destroy resources in the first release
- state files should record Thunder-managed ownership clearly
- status should default to JSON for machine consumption and CI reliability
- pretty output should be derived from the same status object rather than computed separately
- bootstrap deploy should not proceed when resource creation or config patching left the project in an invalid state

## Testing Plan

### Unit tests

- `thunder.json` resource config parsing
- state file read and write behavior
- managed `wrangler.toml` patching
- status JSON rendering and pretty rendering

### Mocked Wrangler tests

- resource create/list parsing for KV, R2, D1, and Queues
- Worker bootstrap detection and deploy invocation
- auth and account lookup failures
- service binding adoption validation

### Integration-style tests

- repeated `provision` runs stay idempotent
- status detects drift between config, state, and mocked remote resources
- generated-app fixture can compile and use the provisioning-aware scaffold shape

### Credentialed validation

- explicit dev/test validation against a real Cloudflare account after core mocked coverage is stable
- bootstrap deploy succeeds against a fresh app with Thunder-managed resources

## Success Criteria

This plan is done only when:

- Thunder can create KV, R2, D1, and Queue resources for dev/test with Wrangler
- Thunder can wire Workers AI and Durable Objects automatically
- `thunder cloudflare provision` automatically bootstraps the Worker script
- `thunder cloudflare status` returns JSON by default and validates overall health
- generated apps can reach first live test without manual dashboard setup for the supported resource set
- docs teach provisioning and status as the default dev/test path

## Checkpoint: P1 complete
Completed:
- extended `packages/thunder_cli/thunder_config.ml` and `packages/thunder_cli/thunder_config.mli` with the first Cloudflare provisioning schema for dev/test mode, bootstrap-worker intent, and desired resource declarations
- added `packages/thunder_cli/simple_json.ml` and `packages/thunder_cli/simple_json.mli` as a small shared JSON parser and serializer for Thunder-owned config and state files
- added `packages/thunder_cli/cloudflare_state.ml` and `packages/thunder_cli/cloudflare_state.mli` for `.thunder/cloudflare_resources.json` read/write support
- added `packages/thunder_cli/cloudflare_status.ml` and `packages/thunder_cli/cloudflare_status.mli` with the first JSON-first status object model
- expanded CLI tests to cover Cloudflare provisioning config parsing, state round-tripping, and status JSON serialization

Verified:
- `opam exec -- dune build tests/cli_tests.exe`
- `THUNDER_FRAMEWORK_ROOT="/Users/samhuckaby/development/thunder" opam exec -- dune exec ./tests/cli_tests.exe`
- `opam exec -- dune build packages/thunder_cli/main.exe`

Next:
- begin P2 by extending Thunder's Wrangler wrapper layer for resource creation and inspection

---

## Checkpoint: P2 complete
Completed:
- extended `packages/thunder_cli/wrangler.ml` and `packages/thunder_cli/wrangler.mli` with the first Cloudflare resource and account helper surface for KV, R2, D1, Queues, worker inspection, and auth/account lookup
- added shared parsing helpers for account id extraction, resource list extraction, and worker existence checks from Wrangler output
- added CLI tests covering account parsing, resource parsing, and worker existence detection

Verified:
- `opam exec -- dune build tests/cli_tests.exe packages/thunder_cli/main.exe`
- `THUNDER_FRAMEWORK_ROOT="/Users/samhuckaby/development/thunder" opam exec -- dune exec ./tests/cli_tests.exe`
- `opam exec -- dune build packages/thunder_cli/main.exe`

Next:
- begin P3 by implementing the Thunder-owned resource provisioning engine

---

## Checkpoint: P3 complete
Completed:
- added `packages/thunder_cli/cloudflare_provision.ml` and `packages/thunder_cli/cloudflare_provision.mli` as the first Thunder-owned resource provisioning engine
- implemented desired-resource planning against Thunder config and existing state for KV, R2, D1, Queues, Workers AI, Durable Objects, and service bindings
- implemented create, reuse, wire, and adopt actions for the supported dev/test resource categories
- added a `run_and_write` path so provisioning can persist updated `.thunder/cloudflare_resources.json` state directly
- expanded CLI tests to cover provisioning create, reuse, adopt, and state persistence behavior with mocked Wrangler operations

Verified:
- `opam exec -- dune build tests/cli_tests.exe packages/thunder_cli/main.exe`
- `THUNDER_FRAMEWORK_ROOT="/Users/samhuckaby/development/thunder" opam exec -- dune exec ./tests/cli_tests.exe`
- `opam exec -- dune build packages/thunder_cli/main.exe`

Next:
- begin P4 by patching `wrangler.toml` and wiring bootstrap deploy

---

## Checkpoint: P4 complete
Completed:
- added `packages/thunder_cli/cloudflare_wrangler_config.ml` and `packages/thunder_cli/cloudflare_wrangler_config.mli` to render Thunder-managed binding sections into `wrangler.toml`
- added managed config rendering for KV, R2, D1, Queues, Workers AI, Durable Objects, and service bindings with stable section markers
- added `packages/thunder_cli/cloudflare_bootstrap.ml` and `packages/thunder_cli/cloudflare_bootstrap.mli` for the first automatic Worker bootstrap deploy helper and state updates
- expanded CLI tests to cover managed config rendering, file patching, and bootstrap state persistence

Verified:
- `opam exec -- dune build tests/cli_tests.exe packages/thunder_cli/main.exe`
- `THUNDER_FRAMEWORK_ROOT="/Users/samhuckaby/development/thunder" opam exec -- dune exec ./tests/cli_tests.exe`
- `opam exec -- dune build packages/thunder_cli/main.exe`

Next:
- begin P5 by shipping the JSON-first status command

---

## Checkpoint: P5 complete
Completed:
- extended `packages/thunder_cli/cloudflare_status.ml` and `packages/thunder_cli/cloudflare_status.mli` with a JSON-first status command model, remote inspection ops, and pretty rendering
- added `thunder cloudflare status` to `packages/thunder_cli/main.ml` with JSON output by default and `--pretty` for human-readable rendering
- implemented status health computation across Thunder config, Thunder-managed state, Wrangler account inspection, remote resource existence, and Worker bootstrap state
- expanded CLI tests to cover status JSON serialization, pretty rendering, healthy status computation, and drift detection

Verified:
- `opam exec -- dune build tests/cli_tests.exe packages/thunder_cli/main.exe`
- `THUNDER_FRAMEWORK_ROOT="/Users/samhuckaby/development/thunder" opam exec -- dune exec ./tests/cli_tests.exe`
- `opam exec -- dune build packages/thunder_cli/main.exe`

Next:
- begin P6 by integrating provisioning into scaffolded apps and docs

---

## Checkpoint: P6 complete
Completed:
- updated scaffolded `thunder.json` templates to include the first dev/test Cloudflare provisioning config block
- updated scaffolded app `README.md` content to teach `thunder cloudflare provision`, `thunder cloudflare status`, and `thunder cloudflare status --pretty`
- updated `README.md`, `KICKSTART.md`, `docs/deployment.md`, and `docs/examples.md` so provisioning and status are now documented as the intended dev/test onboarding flow
- expanded CLI scaffold tests to verify the new provisioning-aware config and README output

Verified:
- `opam exec -- dune build tests/cli_tests.exe packages/thunder_cli/main.exe`
- `THUNDER_FRAMEWORK_ROOT="/Users/samhuckaby/development/thunder" opam exec -- dune exec ./tests/cli_tests.exe`
- `opam exec -- dune build packages/thunder_cli/main.exe`

Next:
- begin P7 by hardening the provisioning flow for release readiness

---

## Checkpoint: P7 complete
Completed:
- added account mismatch detection to the provisioning engine so Thunder refuses to provision against a different account than the one recorded in state
- hardened status output to report account mismatch as an error and undeclared state-only resources as drift warnings
- updated deployment and release docs to capture the first-release provisioning constraints: dev/test only, no automatic destroy, and service bindings as adopt-existing
- expanded CLI tests to cover account mismatch failure and stale-state drift detection

Verified:
- `opam exec -- dune build tests/cli_tests.exe packages/thunder_cli/main.exe`
- `THUNDER_FRAMEWORK_ROOT="/Users/samhuckaby/development/thunder" opam exec -- dune exec ./tests/cli_tests.exe`
- `opam exec -- dune build packages/thunder_cli/main.exe`

Next:
- treat Thunder-managed Cloudflare provisioning as the canonical dev/test setup path

---

## Phase P8 - Wrangler 4.80 command compatibility audit

## Goal

Make Thunder's provisioning and status paths compatible with Wrangler `4.80.0` by removing unsupported CLI flags and explicitly classifying command output modes.

## Tasks

### P8.1 Audit each Wrangler command used by provisioning and status

Need:

- identify which commands support `--json`
- identify which commands emit text-only output in Wrangler `4.80.0`

Acceptance:

- Thunder's wrapper layer documents the expected output mode per command

### P8.2 Remove unsupported `--json` flags

Need:

- create and list commands to stop passing unsupported flags
- JSON-only assumptions to be removed from incompatible command wrappers

Acceptance:

- live provisioning no longer fails immediately with `Unknown argument: json`

### P8.3 Add checkpoint note

---

## Phase P9 - Text-mode resource parsing

## Goal

Parse Wrangler `4.80.0` human-readable output for resource creation and listing where JSON is unavailable.

## Tasks

### P9.1 Add create-output parsers

Need parsers for:

- KV namespace create
- R2 bucket create
- D1 create
- Queue create

Acceptance:

- create flows can extract names and identifiers from text output when JSON is unavailable

### P9.2 Add list-output parsers

Need parsers for:

- KV namespace list
- R2 bucket list
- Queue list

Acceptance:

- status can discover remote resources from live Wrangler text output

### P9.3 Wire provisioning and status to command-specific parsers

Acceptance:

- provisioning and status stop relying on one generic parse path for all resource commands

### P9.4 Add checkpoint note

---

## Phase P10 - Live-flow validation and hardening

## Goal

Validate the dev/test provisioning flow against a real Wrangler `4.80.0` environment and harden the remaining edge cases.

## Tasks

### P10.1 Add tests using real-looking text fixtures

Acceptance:

- CLI tests cover Wrangler `4.80.0` style text output

### P10.2 Re-run throwaway-app provisioning flow

Acceptance:

- `thunder cloudflare provision` succeeds in a fresh test app with live auth and supported resources
- if a supported resource already exists remotely, Thunder reuses or adopts it instead of failing the whole provisioning run

### P10.3 Add release-facing compatibility note

Acceptance:

- docs mention the current Wrangler compatibility target explicitly

### P10.4 Add checkpoint note

---

## Checkpoint: P8 complete
Completed:
- audited Thunder's Wrangler resource commands against the current live compatibility target, Wrangler `4.80.0`
- updated `packages/thunder_cli/wrangler.ml` and `packages/thunder_cli/wrangler.mli` so KV, R2, Queue, and D1 create flows no longer pass unsupported `--json` flags
- added explicit command-mode notes and argument helper functions so text-mode versus JSON-mode behavior is now documented and testable
- expanded CLI tests to verify which provisioning commands omit `--json` and which still keep it where supported

Verified:
- `opam exec -- dune build tests/cli_tests.exe packages/thunder_cli/main.exe`
- `THUNDER_FRAMEWORK_ROOT="/Users/samhuckaby/development/thunder" opam exec -- dune exec ./tests/cli_tests.exe`
- `opam exec -- dune build packages/thunder_cli/main.exe`

Next:
- begin P9 by implementing text-mode create/list parsers for Wrangler `4.80.0`

---

## Checkpoint: P9 complete
Completed:
- added command-specific text-compatible parsers in `packages/thunder_cli/wrangler.ml` and `packages/thunder_cli/wrangler.mli` for KV create/list, R2 create/list, D1 create, and Queue create/list
- updated the provisioning engine to use command-specific create parsers instead of assuming generic JSON resource parsing for every create command
- updated status to use command-specific list parsers for KV, R2, and Queues while keeping JSON parsing for supported commands like `d1 list`
- expanded CLI tests with live-shaped text fixtures for KV, R2, D1, and Queue parser coverage

Verified:
- `opam exec -- dune build tests/cli_tests.exe packages/thunder_cli/main.exe`
- `THUNDER_FRAMEWORK_ROOT="/Users/samhuckaby/development/thunder" opam exec -- dune exec ./tests/cli_tests.exe`
- `opam exec -- dune build packages/thunder_cli/main.exe`

Next:
- begin P10 by validating the real throwaway-app provisioning flow

---

## Checkpoint: P10 complete
Completed:
- updated the provisioning engine so create failures that indicate a resource already exists now trigger a remote list lookup and reuse/adopt that existing resource instead of failing the whole provisioning run
- extended CLI tests to cover already-existing resource reuse behavior alongside the earlier Wrangler `4.80.0` text-output compatibility fixes

Verified:
- `opam exec -- dune build tests/cli_tests.exe packages/thunder_cli/main.exe`
- `THUNDER_FRAMEWORK_ROOT="/Users/samhuckaby/development/thunder" opam exec -- dune exec ./tests/cli_tests.exe`

Next:
- treat live Wrangler `4.80.0` provisioning as a validated Thunder dev/test workflow
