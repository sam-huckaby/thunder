# Examples

## hello_site

Simple HTML route at `/`.

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
