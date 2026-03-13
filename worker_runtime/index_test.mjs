import test from "node:test";
import assert from "node:assert/strict";

globalThis.__THUNDER_SKIP_BOOTSTRAP__ = true;
const { __internal } = await import("./index.mjs");
const { waitForGlobalHandler } = await import("./compiled_runtime_bootstrap.mjs");
const {
  init: initAppAbi,
  handle: handleAppAbi,
  resetForTests,
  THUNDER_ABI_JSON_VERSION,
  THUNDER_ABI_INIT_CAPABILITIES,
  __internal: abiInternal,
} = await import("./app_abi.mjs");

test("encodeRequest preserves method/url/headers/body", async () => {
  const headers = new Headers();
  headers.append("content-type", "application/json");
  headers.append("x-test", "1");
  headers.append("x-test", "2");

  const request = new Request("https://example.com/echo?x=1", {
    method: "POST",
    headers,
    body: JSON.stringify({ ok: true }),
  });

  const encoded = await __internal.encodeRequest(
    request,
    { GREETING: "hello", COUNT: 2, SKIP: { nested: true } },
    { waitUntil() {} }
  );

  assert.equal(encoded.v, 1);
  assert.equal(encoded.method, "POST");
  assert.equal(encoded.url, "https://example.com/echo?x=1");
  assert.equal(
    encoded.headers.some(([k]) => k === "content-type"),
    true
  );
  assert.deepEqual(encoded.headers.filter(([k]) => k === "x-test"), [["x-test", "1, 2"]]);
  assert.equal(encoded.env_bindings.some(([k]) => k === "GREETING"), true);
  assert.equal(encoded.ctx_features.includes("waitUntil"), true);
  assert.equal(encoded.ctx_features.includes("passThroughOnException"), false);
  assert.equal(typeof encoded.body_base64, "string");
  assert.equal(
    encoded.body_base64,
    Buffer.from(JSON.stringify({ ok: true }), "utf8").toString("base64")
  );
});

test("encodeRequest matches ABI fixture shape", async () => {
  const request = new Request("https://example.com/upload", {
    method: "PUT",
    headers: { "content-type": "text/plain;charset=utf-8" },
    body: "storm",
  });

  const encoded = await __internal.encodeRequest(
    request,
    { GREETING: "hi", ENABLED: true, COUNT: 7 },
    { waitUntil() {}, passThroughOnException() {} }
  );

  assert.deepEqual(encoded, {
    v: 1,
    method: "PUT",
    url: "https://example.com/upload",
    headers: [["content-type", "text/plain;charset=utf-8"]],
    body: "storm",
    body_base64: Buffer.from("storm", "utf8").toString("base64"),
    env_bindings: [
      ["GREETING", "hi"],
      ["ENABLED", "true"],
      ["COUNT", "7"],
    ],
    ctx_features: ["waitUntil", "passThroughOnException"],
  });
});

test("decodeResponsePayload preserves repeated headers", async () => {
  const response = __internal.decodeResponsePayload({
    status: 302,
    headers: [
      ["location", "https://example.com/next"],
      ["set-cookie", "a=1"],
      ["set-cookie", "b=2"],
    ],
    body: "redirect",
  });

  assert.equal(response.status, 302);
  assert.equal(response.headers.get("location"), "https://example.com/next");
  assert.equal(response.headers.get("set-cookie"), "a=1, b=2");
  assert.equal(await response.text(), "redirect");
});

test("decodeResponsePayload supports body_base64", async () => {
  const response = __internal.decodeResponsePayload({
    status: 200,
    headers: [["content-type", "application/octet-stream"]],
    body_base64: Buffer.from("storm-bytes", "utf8").toString("base64"),
  });

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("content-type"), "application/octet-stream");
  assert.equal(await response.text(), "storm-bytes");
});

test("decodeResponsePayload rejects malformed payload", () => {
  assert.throws(
    () =>
      __internal.decodeResponsePayload({
        status: 200,
        headers: "not-an-array",
        body: "ok",
      }),
    /missing array 'headers'/
  );
});

test("decodeResponsePayload rejects missing body fields", () => {
  assert.throws(
    () =>
      __internal.decodeResponsePayload({
        status: 204,
        headers: [],
      }),
    /must include 'body' or 'body_base64'/
  );
});

test("resolveRelativeModuleUrl returns URL for valid relative path", () => {
  const resolved = __internal.resolveRelativeModuleUrl("./index.mjs");
  assert.ok(resolved instanceof URL);
  assert.equal(resolved.pathname.endsWith("/worker_runtime/index.mjs"), true);
});

test("waitForGlobalHandler tolerates delayed registration", async () => {
  delete globalThis.thunder_handle_json;
  setTimeout(() => {
    globalThis.thunder_handle_json = () => "ok";
  }, 5);

  const found = await waitForGlobalHandler({ timeoutMs: 200, intervalMs: 5 });
  assert.equal(found, true);

  delete globalThis.thunder_handle_json;
});

test("app_abi init caches adapter loading", async () => {
  resetForTests();
  let calls = 0;
  globalThis.__THUNDER_WASM_SHIM__ = {
    async handle() {
      calls += 1;
      return JSON.stringify({ status: 200, headers: [], body: "ok" });
    },
  };

  const first = await initAppAbi({});
  const second = await initAppAbi({});

  assert.equal(calls, 0);
  assert.equal(first.abi_version, THUNDER_ABI_JSON_VERSION);
  assert.equal(first.app_id, abiInternal.manifest.app_id);
  assert.equal(typeof first.asset_base_url, "string");
  assert.deepEqual(first.capabilities, THUNDER_ABI_INIT_CAPABILITIES);
  assert.equal(first.backend_kind, "shim-override");
  assert.equal(Object.hasOwn(first, "requested_backend"), false);
  assert.equal(first.backend_kind, "shim-override");
  assert.deepEqual(first, second);
  assert.equal(calls, 0);
  delete globalThis.__THUNDER_WASM_SHIM__;
  resetForTests();
});

test("app_abi resolveRuntimeBackend prefers shim override", async () => {
  resetForTests();
  globalThis.__THUNDER_WASM_SHIM__ = {
    async handle() {
      return JSON.stringify({ status: 200, headers: [], body: "ok" });
    },
  };
  const backend = abiInternal.resolveRuntimeBackend();
  assert.equal(backend.kind, "shim-override");
  delete globalThis.__THUNDER_WASM_SHIM__;
  resetForTests();
});

test("app_abi init rejects unsupported ABI versions", async () => {
  resetForTests();
  await assert.rejects(
    () =>
      initAppAbi({ initPayload: { abi_version: 2 } }),
    /Unsupported Thunder ABI version: 2/
  );
  resetForTests();
});

test("app_abi handle encodes request and decodes response", async () => {
  resetForTests();
  const request = new Request("https://example.com/abi", { method: "POST", body: "wind" });
  globalThis.__THUNDER_WASM_SHIM__ = {
    async handle(payloadText) {
      const payload = JSON.parse(payloadText);
      assert.equal(payload.v, 1);
      assert.equal(payload.method, "POST");
      assert.equal(payload.body, "wind");
      return JSON.stringify({ status: 201, headers: [["x-abi", "ok"]], body: "storm" });
    },
  };
  const response = await handleAppAbi({
    request,
    env: { GREETING: "hi" },
    ctx: { waitUntil() {} },
    encodeRequest: __internal.encodeRequest,
    decodeResponsePayload: __internal.decodeResponsePayload,
  });

  assert.equal(response.status, 201);
  assert.equal(response.headers.get("x-abi"), "ok");
  assert.equal(await response.text(), "storm");
  delete globalThis.__THUNDER_WASM_SHIM__;
  resetForTests();
});

test("app_abi manifest defaults resolve asset base url", () => {
  const normalized = abiInternal.normalizeInitPayload({});
  assert.equal(normalized.app_id, abiInternal.manifest.app_id);
  assert.equal(normalized.abi_version, abiInternal.manifest.abi_version);
  assert.equal(typeof normalized.asset_base_url, "string");
  assert.equal(
    normalized.asset_base_url.endsWith(`/${abiInternal.manifest.assets_dir}/`),
    true
  );
});

test("worker host keeps init payload minimal", () => {
  assert.deepEqual(__internal.makeInitPayload({}), {});
  assert.deepEqual(__internal.makeInitPayload({ THUNDER_RUNTIME_BACKEND: "ignored" }), {});
});
