import test from "node:test";
import assert from "node:assert/strict";

import { __internal } from "./index.mjs";

test("encodeRequest preserves method/url/headers/body", async () => {
  const request = new Request("https://example.com/echo?x=1", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-test": "1",
    },
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
  assert.equal(encoded.env_bindings.some(([k]) => k === "GREETING"), true);
  assert.equal(encoded.ctx_features.includes("waitUntil"), true);
  assert.equal(typeof encoded.body_base64, "string");
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
