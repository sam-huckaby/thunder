import {
  handle as handleAppAbi,
  init as initAppAbi,
  isRuntimeInitialized,
} from "./app_abi.mjs";

function resolveRelativeModuleUrl(relativePath) {
  try {
    const baseUrl = import.meta?.url;
    if (typeof baseUrl !== "string" || baseUrl === "") return null;
    return new URL(relativePath, baseUrl);
  } catch (_error) {
    return null;
  }
}

function bytesToBase64(bytes) {
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary);
}

function base64ToBytes(value) {
  const binary = atob(value);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}

function normalizeEnvBindings(env) {
  if (!env || typeof env !== "object") return [];

  const bindings = [];
  for (const [key, value] of Object.entries(env)) {
    if (
      typeof value === "string" ||
      typeof value === "number" ||
      typeof value === "boolean"
    ) {
      bindings.push([key, String(value)]);
    }
  }
  return bindings;
}

function normalizeCtxFeatures(ctx) {
  if (!ctx || typeof ctx !== "object") return [];

  const features = [];
  if (typeof ctx.waitUntil === "function") features.push("waitUntil");
  if (typeof ctx.passThroughOnException === "function") {
    features.push("passThroughOnException");
  }
  return features;
}

async function encodeRequest(request, env, ctx) {
  const headers = [];
  request.headers.forEach((value, name) => {
    headers.push([name, value]);
  });

  const rawBody = new Uint8Array(await request.arrayBuffer());
  const body = new TextDecoder().decode(rawBody);

  return {
    v: 1,
    method: request.method,
    url: request.url,
    headers,
    body,
    body_base64: bytesToBase64(rawBody),
    env_bindings: normalizeEnvBindings(env),
    ctx_features: normalizeCtxFeatures(ctx),
  };
}

function decodeResponsePayload(payload) {
  if (!payload || typeof payload !== "object") {
    throw new Error("Runtime payload is not an object.");
  }

  if (typeof payload.status !== "number") {
    throw new Error("Runtime payload is missing numeric 'status'.");
  }

  if (!Array.isArray(payload.headers)) {
    throw new Error("Runtime payload is missing array 'headers'.");
  }

  const headers = new Headers();
  for (const headerPair of payload.headers) {
    if (!Array.isArray(headerPair) || headerPair.length !== 2) {
      throw new Error("Runtime payload contains malformed header tuple.");
    }
    const [name, value] = headerPair;
    if (typeof name !== "string" || typeof value !== "string") {
      throw new Error("Runtime payload header tuple must be [string, string].");
    }
    headers.append(name, value);
  }

  if (typeof payload.body_base64 === "string") {
    const bytes = base64ToBytes(payload.body_base64);
    return new Response(bytes, { status: payload.status, headers });
  }

  if (typeof payload.body === "string") {
    return new Response(payload.body, { status: payload.status, headers });
  }

  throw new Error("Runtime payload must include 'body' or 'body_base64'.");
}

function makeInitFailureResponse(error) {
  const message =
    error instanceof Error ? error.message : "Unknown Wasm runtime initialization failure.";
  return new Response(`Thunder Wasm runtime initialization failed: ${message}`, {
    status: 500,
    headers: { "content-type": "text/plain; charset=utf-8" },
  });
}

function makeRuntimeFailureResponse(error) {
  const message = error instanceof Error ? error.message : "Unknown runtime invocation failure.";
  return new Response(`Thunder runtime invocation failed: ${message}`, {
    status: 500,
    headers: { "content-type": "text/plain; charset=utf-8" },
  });
}

function makeInitPayload(env) {
  return {};
}

async function invokeRuntime(request, env, ctx) {
  const initPayload = makeInitPayload(env);
  await initAppAbi({ initPayload });
  return handleAppAbi({
    request,
    env,
    ctx,
    initPayload,
    encodeRequest,
    decodeResponsePayload,
  });
}

export default {
  async fetch(request, env, ctx) {
    try {
      return await invokeRuntime(request, env, ctx);
    } catch (error) {
      if (!isRuntimeInitialized()) {
        return makeInitFailureResponse(error);
      }
      return makeRuntimeFailureResponse(error);
    }
  },
};

export const __internal = {
  resolveRelativeModuleUrl,
  encodeRequest,
  decodeResponsePayload,
  normalizeEnvBindings,
  normalizeCtxFeatures,
  makeInitPayload,
};
