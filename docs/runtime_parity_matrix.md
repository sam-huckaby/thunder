# Runtime Parity Matrix

This matrix tracks preview validation for Thunder's supported Worker runtime targets.

Runtime targets:

- `js`
- `wasm`

Representative routes and expectations:

| Behavior | Route / Input | Expected result | Covered by tests | Preview status |
| --- | --- | --- | --- | --- |
| GET HTML | `GET /` | `200`, HTML body renders | `tests/integration_tests.ml` | pass |
| POST JSON echo | `POST /echo` with JSON body | `200`, response body equals request body | `tests/integration_tests.ml` | pass |
| Redirect | `GET /redirect` | `302`, `location` preserved | `tests/integration_tests.ml` | pending route smoke |
| Repeated cookies | `GET /cookies` | repeated `set-cookie` preserved | `tests/integration_tests.ml` | pending route smoke |
| Env bindings | `GET /env` with `GREETING` binding | `200`, body reflects binding | `tests/integration_tests.ml` | pending route smoke |
| Context features | `GET /ctx` with `waitUntil` capability | `200`, body confirms feature | `tests/integration_tests.ml` | pending route smoke |
| 404 | `GET /missing` | `404` | `tests/integration_tests.ml` | pass |
| 500 recover path | `GET /boom` | `500` via recover middleware | `tests/integration_tests.ml` | pending route smoke |
| Binary response decode | runtime `body_base64` payload | bytes preserved | `worker_runtime/index_test.mjs` | pass via runtime tests |

Validation procedure:

1. Build and stage artifacts with `dune build`.
2. Deploy a preview with `scripts/preview_smoke.sh js` and `scripts/preview_smoke.sh wasm`.
3. Exercise the matrix routes against the preview deployment.
4. Record any divergence before release.

Recording rules:

- mark a cell `pass` only after validating the deployed preview response manually or with release-gated smoke checks
- any `fail` blocks release work until the divergence is understood

Latest credentialed preview result:

- `js`: preview smoke attempted on 2026-03-20 but blocked by Cloudflare auth error `Invalid access token [code: 9109]`
- `wasm`: preview smoke attempted on 2026-03-20 but blocked by Cloudflare auth error `Invalid access token [code: 9109]`

Release criteria:

- both supported targets pass every applicable row in this matrix
- preview smoke completes successfully in a credentialed environment
