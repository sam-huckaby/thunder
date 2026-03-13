# Examples

These examples demonstrate the Thunder API locally and in tests. They are not the app that Thunder deploys from the repository by default.

The deployed app in this repo is defined in `packages/thunder_worker/wasm_entry.ml`.

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
