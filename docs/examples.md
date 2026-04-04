# Examples

These examples demonstrate the Thunder API locally and in tests. They are not the app that Thunder deploys from the repository by default.

The deployed app in this repo is defined in `packages/thunder_worker/wasm_entry.ml`.

For the generated-app workflow, the equivalent user-edited file is `app/routes.ml` inside the scaffolded app.

## hello_site

Simple HTML route at `/`.

Use this example as the closest reference when building your first page in `packages/thunder_worker/wasm_entry.ml`.

## json_api

- `GET /health`
- `POST /echo`

## cookies

Reads `Cookie` request header and writes `Set-Cookie` response headers.

## params

Demonstrates path param (`:id`) and query access.

## middleware

Demonstrates `logger`, `recover`, and response header injection.

## env_binding

Reads Worker env values from request-bound runtime context.

## cloudflare_ai

Shows how `Thunder.Worker.AI.run_json` can be used from an async Thunder route.

## cloudflare_d1

Single-product D1 example with `first` and `all` query flows.

## cloudflare_service

Single-product service binding example with health and search proxy routes.

## cloudflare_storage

Shows KV and R2 access through `Thunder.Worker.KV` and `Thunder.Worker.R2`.

## cloudflare_coordination

Shows queue send and Durable Object invocation through `Thunder.Worker.Queues` and `Thunder.Worker.Durable_object`.

## cloudflare_full_stack

Shows a combined example using D1, service bindings, Workers AI, and the generic binding primitive in one Thunder app.

## cloudflare_ingest_pipeline

Combined example using R2, Queues, D1, and a service binding in an ingest workflow.

## cloudflare_support_assistant

Combined example using KV, a service binding, Workers AI, and the generic primitive in a support assistant workflow.

## zephyr_kv_inspector

Shows how Thunder can inspect Zephyr-oriented Cloudflare bindings such as `ze_env`, `ze_files`, and `ze_snapshots` without assuming Zephyr's internal storage schema.

## Example Binding Config Snippets

These examples assume binding names like the following in `wrangler.toml`:

```toml
[[kv_namespaces]]
binding = "MY_KV"
id = "<kv-id>"

[[r2_buckets]]
binding = "FILES"
bucket_name = "<bucket-name>"

[[queues.producers]]
binding = "JOBS"
queue = "<queue-name>"

[[d1_databases]]
binding = "DB"
database_name = "<db-name>"
database_id = "<db-id>"

[ai]
binding = "AI"

[[services]]
binding = "API"
service = "<service-name>"

[[durable_objects.bindings]]
name = "MY_DO"
class_name = "MyDurableObject"
```

Zephyr-oriented inspection examples expect bindings named `ze_env`, `ze_files`, and `ze_snapshots`.

For supported dev/test flows, the preferred setup path is:

```bash
thunder cloudflare provision
thunder cloudflare status
thunder cloudflare status --pretty
```

That provisioning path is intended to replace manual dashboard setup for the supported resource set.

These Cloudflare-focused examples show the intended first-class Thunder API shape through `Thunder.Worker.*`. Internally, those bindings are currently implemented by the JS-only `thunder.worker_js` layer so native test executables stay stable.

## AI Test Strategy

- routine CI should use mocked host RPC behavior for AI paths rather than live inference
- local and release validation can use real Workers AI bindings when credentials and billing context are intentional
- Thunder currently treats AI responses as buffered JSON/text results; streaming AI output remains deferred
