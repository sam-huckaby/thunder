import test from "node:test";
import assert from "node:assert/strict";

globalThis.__THUNDER_SKIP_BOOTSTRAP__ = true;
const { __internal } = await import("./index.mjs");
const requestContextModule = await import("./request_context.mjs");
const { waitForGlobalHandler } = await import("./compiled_runtime_bootstrap.mjs");
const {
  handleCompiledJsRuntimePayload,
  initCompiledJsRuntimeBackend,
  resetCompiledJsRuntimeBackendForTests,
} = await import("./compiled_js_runtime_backend.mjs");
const {
  init: initAppAbi,
  handle: handleAppAbi,
  resetForTests,
  THUNDER_ABI_JSON_VERSION,
  THUNDER_ABI_INIT_CAPABILITIES,
  __internal: abiInternal,
} = await import("./app_abi.mjs");

const { enterRequestContext, getRequestContextStrategy, __internal: requestContextInternal } =
  requestContextModule;

test.afterEach(() => {
  requestContextInternal.resetForTests();
  delete globalThis.__THUNDER_WASM_SHIM__;
  delete globalThis.thunder_handle_json;
  resetForTests();
});

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
    { waitUntil() {} },
    "req-123"
  );

  assert.equal(encoded.v, __internal.THUNDER_ABI_REQUEST_VERSION);
  assert.equal(encoded.request_id, "req-123");
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
    { waitUntil() {}, passThroughOnException() {} },
    "req-fixture"
  );

  assert.deepEqual(encoded, {
    v: __internal.THUNDER_ABI_REQUEST_VERSION,
    request_id: "req-fixture",
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
  if (abiInternal.manifest.runtime_kind === "wasm") {
    assert.equal(typeof first.asset_base_url, "string");
  } else {
    assert.equal(first.asset_base_url, null);
  }
  assert.deepEqual(first.capabilities, THUNDER_ABI_INIT_CAPABILITIES);
  assert.equal(first.backend_kind, "shim-override");
  assert.equal(Object.hasOwn(first, "requested_backend"), false);
  assert.equal(first.backend_kind, "shim-override");
  assert.deepEqual(first, second);
  assert.equal(calls, 0);
});

test("app_abi resolveRuntimeBackend prefers shim override", async () => {
  globalThis.__THUNDER_WASM_SHIM__ = {
    async handle() {
      return JSON.stringify({ status: 200, headers: [], body: "ok" });
    },
  };
  const backend = abiInternal.resolveRuntimeBackend();
  assert.equal(backend.kind, "shim-override");
});

test("app_abi resolves manifest runtime kind", () => {
  assert.equal(abiInternal.resolveManifestRuntimeKind(), abiInternal.manifest.runtime_kind ?? "wasm");
});

test("app_abi resolves JS backend when requested", () => {
  const backend = abiInternal.resolveRuntimeBackend("js");
  assert.equal(backend.kind, "compiled-js-runtime");
});

test("app_abi resolves Wasm backend when requested", () => {
  const backend = abiInternal.resolveRuntimeBackend("wasm");
  assert.equal(backend.kind, "compiled-wasm-runtime");
});

test("compiled JS runtime backend uses registered global handler", async () => {
  resetCompiledJsRuntimeBackendForTests();
  globalThis.thunder_handle_json = (payload) =>
    JSON.stringify({ status: 200, headers: [["x-kind", "js"]], body: payload });

  const initResult = await initCompiledJsRuntimeBackend();
  assert.equal(initResult.kind, "compiled-js-runtime");

  const response = await handleCompiledJsRuntimePayload("storm");
  assert.equal(JSON.parse(response).body, "storm");

  resetCompiledJsRuntimeBackendForTests();
});

test("app_abi init uses compiled backend from manifest", async () => {
  globalThis.thunder_handle_json = () => JSON.stringify({ status: 200, headers: [], body: "ok" });
  const result = await initAppAbi({});
  assert.equal(
    result.backend_kind,
    abiInternal.manifest.runtime_kind === "js"
      ? "compiled-js-runtime"
      : "compiled-wasm-runtime"
  );
});

test("app_abi init rejects unsupported ABI versions", async () => {
  await assert.rejects(
    () =>
      initAppAbi({ initPayload: { abi_version: 2 } }),
    /Unsupported Thunder ABI version: 2/
  );
});

test("app_abi init rejects missing expected capabilities", async () => {
  await assert.rejects(
    () =>
      initAppAbi({
        initPayload: { expected_capabilities: ["missing_capability"] },
      }),
    /missing required capabilities: missing_capability/
  );
});

test("app_abi handle encodes request and decodes response", async () => {
  const request = new Request("https://example.com/abi", { method: "POST", body: "wind" });
  globalThis.__THUNDER_WASM_SHIM__ = {
    async handle(payloadText) {
      const payload = JSON.parse(payloadText);
      assert.equal(payload.v, __internal.THUNDER_ABI_REQUEST_VERSION);
      assert.equal(typeof payload.request_id, "string");
      assert.equal(payload.method, "POST");
      assert.equal(payload.body, "wind");
      return JSON.stringify({ status: 201, headers: [["x-abi", "ok"]], body: "storm" });
    },
  };
  const response = await handleAppAbi({
    request,
    env: { GREETING: "hi" },
    ctx: { waitUntil() {} },
    encodeRequest: (nextRequest, nextEnv, nextCtx) =>
      __internal.encodeRequest(nextRequest, nextEnv, nextCtx, "req-handle-test"),
    decodeResponsePayload: __internal.decodeResponsePayload,
  });

  assert.equal(response.status, 201);
  assert.equal(response.headers.get("x-abi"), "ok");
  assert.equal(await response.text(), "storm");
});

test("app_abi manifest defaults resolve asset base url", () => {
  const normalized = abiInternal.normalizeInitPayload({});
  assert.equal(normalized.app_id, abiInternal.manifest.app_id);
  assert.equal(normalized.abi_version, abiInternal.manifest.abi_version);
  if (abiInternal.manifest.runtime_kind === "wasm") {
    assert.equal(typeof normalized.asset_base_url, "string");
    assert.equal(
      normalized.asset_base_url.endsWith(`/${abiInternal.manifest.assets_dir}/`),
      true
    );
  } else {
    assert.equal(normalized.asset_base_url, null);
  }
});

test("worker host keeps init payload minimal", () => {
  assert.deepEqual(__internal.makeInitPayload({}), {
    expected_capabilities: [
      "async_handlers",
      "request_context_raw_env",
      "request_context_raw_ctx",
      "binding_rpc",
      "binary_response_payload",
    ],
    request_context_strategy: getRequestContextStrategy("auto"),
  });
  assert.deepEqual(__internal.makeInitPayload({ THUNDER_REQUEST_CONTEXT_STRATEGY: "map" }), {
    expected_capabilities: [
      "async_handlers",
      "request_context_raw_env",
      "request_context_raw_ctx",
      "binding_rpc",
      "binary_response_payload",
    ],
    request_context_strategy: "map",
  });
});

test("request context uses ALS store when available", async () => {
  requestContextInternal.setStrategyOverrideForTests("als");
  const context = enterRequestContext({ TOKEN: "secret" }, { waitUntil() {} });

  const observed = await context.run(async () => {
    await Promise.resolve();
    return globalThis.__thunder_get_env();
  });

  assert.deepEqual(observed, { TOKEN: "secret" });
  context.exit();
});

test("request context keeps ALS stores isolated under concurrency", async () => {
  requestContextInternal.setStrategyOverrideForTests("als");
  const first = enterRequestContext({ TOKEN: "first" }, {});
  const second = enterRequestContext({ TOKEN: "second" }, {});

  const [left, right] = await Promise.all([
    first.run(async () => {
      await new Promise((resolve) => setTimeout(resolve, 5));
      return globalThis.__thunder_get_env();
    }),
    second.run(async () => {
      await Promise.resolve();
      return globalThis.__thunder_get_env();
    }),
  ]);

  assert.deepEqual(left, { TOKEN: "first" });
  assert.deepEqual(right, { TOKEN: "second" });
  first.exit();
  second.exit();
});

test("request context map fallback requires request id and cleans up", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  const context = enterRequestContext({ TOKEN: "secret" }, { waitUntil() {} });

  assert.equal(requestContextInternal.requestContextMap.size, 1);
  const observed = await context.run(async () => {
    await Promise.resolve();
    return globalThis.__thunder_get_env(context.requestId);
  });

  assert.deepEqual(observed, { TOKEN: "secret" });
  context.exit();
  assert.equal(requestContextInternal.requestContextMap.size, 0);
});

test("worker fetch cleans up map request context after success", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  globalThis.__THUNDER_WASM_SHIM__ = {
    async handle(payloadText) {
      const payload = JSON.parse(payloadText);
      assert.deepEqual(globalThis.__thunder_get_env(payload.request_id), {
        THUNDER_REQUEST_CONTEXT_STRATEGY: "map",
        GREETING: "hi",
      });
      return JSON.stringify({ status: 200, headers: [], body: "ok" });
    },
  };

  const request = new Request("https://example.com/runtime");
  const response = await (await import("./index.mjs")).default.fetch(request, {
    THUNDER_REQUEST_CONTEXT_STRATEGY: "map",
    GREETING: "hi",
  }, {});

  assert.equal(await response.text(), "ok");
  assert.equal(requestContextInternal.requestContextMap.size, 0);
});

test("worker fetch cleans up map request context after runtime failure", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  globalThis.__THUNDER_WASM_SHIM__ = {
    async handle() {
      throw new Error("shim failure");
    },
  };

  const response = await (await import("./index.mjs")).default.fetch(
    new Request("https://example.com/runtime"),
    { THUNDER_REQUEST_CONTEXT_STRATEGY: "map" },
    {}
  );

  assert.equal(response.status, 500);
  assert.equal(requestContextInternal.requestContextMap.size, 0);
});

test("map request context returns to zero after concurrent fetch stress", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  const workerModule = await import("./index.mjs");
  globalThis.__THUNDER_WASM_SHIM__ = {
    async handle(payloadText) {
      const payload = JSON.parse(payloadText);
      await Promise.resolve();
      assert.equal(typeof payload.request_id, "string");
      return JSON.stringify({ status: 200, headers: [], body: payload.request_id });
    },
  };

  await Promise.all(
    Array.from({ length: 25 }, (_, index) =>
      workerModule.default.fetch(
        new Request(`https://example.com/runtime/${index}`),
        { THUNDER_REQUEST_CONTEXT_STRATEGY: "map" },
        {}
      )
    )
  );

  assert.equal(requestContextInternal.requestContextMap.size, 0);
});

test("binding RPC rejects unsupported ops", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  const context = enterRequestContext({ GREETING: "hi" }, {});

  const result = await globalThis.__thunder_binding_rpc(context.requestId, "kv.list", {});

  assert.deepEqual(result, {
    ok: false,
    error: {
      code: "binding_rpc_invalid_request",
      message: "Unsupported Thunder binding RPC op: kv.list",
    },
  });

  context.exit();
});

test("binding RPC validates args shape", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  const context = enterRequestContext({ GREETING: "hi" }, {});

  const result = await globalThis.__thunder_binding_rpc(context.requestId, "bad", []);

  assert.deepEqual(result, {
    ok: false,
    error: {
      code: "binding_rpc_invalid_request",
      message: "Thunder binding RPC args must be an object when provided.",
    },
  });

  context.exit();
});

test("binding RPC kv.get returns text values", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  const context = enterRequestContext(
    {
      MY_KV: {
        async get(key, options) {
          assert.equal(key, "welcome");
          assert.deepEqual(options, { type: "text" });
          return "hello";
        },
      },
    },
    {}
  );

  const result = await globalThis.__thunder_binding_rpc(context.requestId, "kv.get", {
    binding: "MY_KV",
    key: "welcome",
  });

  assert.deepEqual(result, { ok: true, value: "hello" });
  context.exit();
});

test("binding RPC kv.get returns bytes as base64", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  const context = enterRequestContext(
    {
      MY_KV: {
        async get(_key, options) {
          assert.deepEqual(options, { type: "arrayBuffer" });
          return Uint8Array.from([97, 98, 99]).buffer;
        },
      },
    },
    {}
  );

  const result = await globalThis.__thunder_binding_rpc(context.requestId, "kv.get", {
    binding: "MY_KV",
    key: "blob",
    type: "bytes",
  });

  assert.deepEqual(result, { ok: true, value_base64: "YWJj" });
  context.exit();
});

test("binding RPC kv.put accepts base64 bytes payload", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  let captured = null;
  const context = enterRequestContext(
    {
      MY_KV: {
        async put(key, value) {
          captured = { key, value: Array.from(value) };
        },
      },
    },
    {}
  );

  const result = await globalThis.__thunder_binding_rpc(context.requestId, "kv.put", {
    binding: "MY_KV",
    key: "blob",
    value_base64: "YWJj",
  });

  assert.deepEqual(result, { ok: true });
  assert.deepEqual(captured, { key: "blob", value: [97, 98, 99] });
  context.exit();
});

test("binding RPC kv.delete calls namespace delete", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  let deletedKey = null;
  const context = enterRequestContext(
    {
      MY_KV: {
        async delete(key) {
          deletedKey = key;
        },
      },
    },
    {}
  );

  const result = await globalThis.__thunder_binding_rpc(context.requestId, "kv.delete", {
    binding: "MY_KV",
    key: "welcome",
  });

  assert.deepEqual(result, { ok: true });
  assert.equal(deletedKey, "welcome");
  context.exit();
});

test("binding RPC r2.get returns text payload", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  const context = enterRequestContext(
    {
      FILES: {
        async get(key) {
          assert.equal(key, "note.txt");
          return { async text() { return "hello r2"; } };
        },
      },
    },
    {}
  );

  const result = await globalThis.__thunder_binding_rpc(context.requestId, "r2.get", {
    binding: "FILES",
    key: "note.txt",
  });

  assert.deepEqual(result, { ok: true, value: "hello r2" });
  context.exit();
});

test("binding RPC r2.put accepts bytes payload", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  let captured = null;
  const context = enterRequestContext(
    {
      FILES: {
        async put(key, value) {
          captured = { key, value: Array.from(value) };
        },
      },
    },
    {}
  );

  const result = await globalThis.__thunder_binding_rpc(context.requestId, "r2.put", {
    binding: "FILES",
    key: "blob.bin",
    value_base64: "YWJj",
  });

  assert.deepEqual(result, { ok: true });
  assert.deepEqual(captured, { key: "blob.bin", value: [97, 98, 99] });
  context.exit();
});

test("binding RPC d1.query prepares binds and returns JSON", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  let preparedSql = null;
  let boundParams = null;
  const context = enterRequestContext(
    {
      DB: {
        prepare(sql) {
          preparedSql = sql;
          return {
            bind(...params) {
              boundParams = params;
              return {
                async first() {
                  return { id: 7, name: "Ada" };
                },
              };
            },
          };
        },
      },
    },
    {}
  );

  const result = await globalThis.__thunder_binding_rpc(context.requestId, "d1.query", {
    binding: "DB",
    sql: "select * from users where id = ?",
    params_json: JSON.stringify([7]),
    action: "first",
  });

  assert.equal(preparedSql, "select * from users where id = ?");
  assert.deepEqual(boundParams, [7]);
  assert.deepEqual(result, {
    ok: true,
    value_json: JSON.stringify({ id: 7, name: "Ada" }),
  });
  context.exit();
});

test("binding RPC ai.run returns JSON payload", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  const context = enterRequestContext(
    {
      AI: {
        async run(model, input, options) {
          assert.equal(model, "@cf/meta/test");
          assert.deepEqual(input, { prompt: "hello" });
          assert.deepEqual(options, { temperature: 0 });
          return { response: "storm" };
        },
      },
    },
    {}
  );

  const result = await globalThis.__thunder_binding_rpc(context.requestId, "ai.run", {
    binding: "AI",
    model: "@cf/meta/test",
    input_json: JSON.stringify({ prompt: "hello" }),
    options_json: JSON.stringify({ temperature: 0 }),
  });

  assert.deepEqual(result, {
    ok: true,
    value_json: JSON.stringify({ response: "storm" }),
  });
  context.exit();
});

test("binding RPC queue.send sends JSON payload", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  let sentValue = null;
  const context = enterRequestContext(
    {
      JOBS: {
        async send(value) {
          sentValue = value;
        },
      },
    },
    {}
  );

  const result = await globalThis.__thunder_binding_rpc(context.requestId, "queue.send", {
    binding: "JOBS",
    value_json: JSON.stringify({ job: "sync" }),
  });

  assert.deepEqual(result, { ok: true });
  assert.deepEqual(sentValue, { job: "sync" });
  context.exit();
});

test("binding RPC queue.send_batch sends JSON array payload", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  let sentBatch = null;
  const context = enterRequestContext(
    {
      JOBS: {
        async sendBatch(messages) {
          sentBatch = messages;
        },
      },
    },
    {}
  );

  const result = await globalThis.__thunder_binding_rpc(context.requestId, "queue.send_batch", {
    binding: "JOBS",
    messages_json: JSON.stringify([{ body: { id: 1 } }, { body: { id: 2 } }]),
  });

  assert.deepEqual(result, { ok: true });
  assert.deepEqual(sentBatch, [{ body: { id: 1 } }, { body: { id: 2 } }]);
  context.exit();
});

test("binding RPC service.fetch returns status and body", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  const context = enterRequestContext(
    {
      API: {
        async fetch(url, init) {
          assert.equal(url, "https://svc.test/ping");
          assert.deepEqual(init, { method: "POST" });
          return new Response("pong", { status: 202 });
        },
      },
    },
    {}
  );

  const result = await globalThis.__thunder_binding_rpc(context.requestId, "service.fetch", {
    binding: "API",
    url: "https://svc.test/ping",
    init_json: JSON.stringify({ method: "POST" }),
  });

  assert.deepEqual(result, {
    ok: true,
    value_json: JSON.stringify({ status: 202, body_text: "pong" }),
  });
  context.exit();
});

test("binding RPC durable_object.call invokes named stub method", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  let requestedName = null;
  const context = enterRequestContext(
    {
      MY_DO: {
        getByName(name) {
          requestedName = name;
          return {
            async greet(person) {
              return { message: `hello ${person}` };
            },
          };
        },
      },
    },
    {}
  );

  const result = await globalThis.__thunder_binding_rpc(
    context.requestId,
    "durable_object.call",
    {
      binding: "MY_DO",
      name: "room-1",
      method: "greet",
      args_json: JSON.stringify(["sam"]),
    }
  );

  assert.equal(requestedName, "room-1");
  assert.deepEqual(result, {
    ok: true,
    value_json: JSON.stringify({ message: "hello sam" }),
  });
  context.exit();
});

test("binding RPC generic invoke returns JSON payload", async () => {
  requestContextInternal.setStrategyOverrideForTests("map");
  const context = enterRequestContext(
    {
      CUSTOM: {
        async ping(name, count) {
          return { name, count, ok: true };
        },
      },
    },
    {}
  );

  const result = await globalThis.__thunder_binding_rpc(
    context.requestId,
    "binding.invoke",
    {
      binding: "CUSTOM",
      method: "ping",
      args_json: JSON.stringify(["sam", 2]),
    }
  );

  assert.deepEqual(result, {
    ok: true,
    value_json: JSON.stringify({ name: "sam", count: 2, ok: true }),
  });
  context.exit();
});
