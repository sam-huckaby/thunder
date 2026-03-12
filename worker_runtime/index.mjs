const DEFAULT_COMPILED_RUNTIME_RELATIVE_PATH = "../dist/worker/thunder_runtime.mjs";

let wasmInstancePromise = null;
let adapterPromise = null;

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

function resolveShimAdapter() {
  const shim = globalThis.__THUNDER_WASM_SHIM__;
  if (!shim || typeof shim.handle !== "function") return null;

  return {
    async handle(jsonPayload) {
      return shim.handle(jsonPayload);
    },
  };
}

async function resolveCompiledModuleAdapter() {
  const compiledRuntimeUrl = resolveRelativeModuleUrl(
    DEFAULT_COMPILED_RUNTIME_RELATIVE_PATH
  );
  if (!compiledRuntimeUrl) return null;

  const existingDocument = globalThis.document;
  const existingCurrentScript = existingDocument?.currentScript;

  try {
    if (!globalThis.document) {
      globalThis.document = {
        currentScript: { src: compiledRuntimeUrl.toString() },
      };
    } else {
      globalThis.document.currentScript = {
        src: compiledRuntimeUrl.toString(),
      };
    }
    await import(compiledRuntimeUrl.toString());
  } catch (_error) {
    if (existingDocument) {
      existingDocument.currentScript = existingCurrentScript;
    } else {
      delete globalThis.document;
    }
    return null;
  }

  if (existingDocument) {
    existingDocument.currentScript = existingCurrentScript;
  } else {
    delete globalThis.document;
  }

  if (typeof globalThis.thunder_handle_json !== "function") {
    return null;
  }

  return {
    async handle(jsonPayload) {
      return globalThis.thunder_handle_json(jsonPayload);
    },
  };
}

function resolveWasmAdapter(instance) {
  const exports = instance.exports ?? {};
  const handler = exports.thunder_handle_json ?? exports.thunder_handle_fetch_json;

  if (typeof handler !== "function") {
    const available = Object.keys(exports).sort().join(", ");
    throw new Error(
      "Unsupported Wasm ABI: expected export thunder_handle_json or thunder_handle_fetch_json. " +
        "Available exports: [" +
        available +
        "]"
    );
  }

  return {
    async handle(jsonPayload) {
      try {
        return handler(jsonPayload);
      } catch (error) {
        throw new Error(
          "Wasm handler invocation failed. Ensure exported function accepts JSON payload and returns JSON.",
          { cause: error }
        );
      }
    },
  };
}

async function loadWasmBytesFromUrl(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to fetch Wasm artifact from ${url.toString()}: ${response.status}`);
  }

  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.length < 8) {
    throw new Error("Wasm artifact is too small to be valid.");
  }

  const magic = [0x00, 0x61, 0x73, 0x6d];
  for (let i = 0; i < magic.length; i += 1) {
    if (bytes[i] !== magic[i]) {
      throw new Error(
        "Wasm artifact is not a valid WebAssembly binary. Verify the worker build output path and artifact type."
      );
    }
  }

  return bytes;
}

async function loadWasmInstance() {
  if (wasmInstancePromise) return wasmInstancePromise;

  wasmInstancePromise = (async () => {
    const override = globalThis.__THUNDER_WASM_MODULE__;

    if (override instanceof WebAssembly.Instance) {
      return override;
    }

    if (override instanceof WebAssembly.Module) {
      const instantiated = await WebAssembly.instantiate(override, { env: {} });
      return instantiated instanceof WebAssembly.Instance
        ? instantiated
        : instantiated.instance;
    }

    if (override instanceof ArrayBuffer || ArrayBuffer.isView(override)) {
      const instantiated = await WebAssembly.instantiate(override, { env: {} });
      return instantiated.instance;
    }

    const wasmUrlOverride =
      override instanceof URL
        ? override.toString()
        : typeof override === "string"
          ? override
          : typeof globalThis.__THUNDER_WASM_URL__ === "string"
            ? globalThis.__THUNDER_WASM_URL__
            : null;

    if (!wasmUrlOverride) {
      throw new Error(
        "Unable to initialize runtime: compiled module adapter unavailable and no Wasm override provided."
      );
    }

    const bytes = await loadWasmBytesFromUrl(wasmUrlOverride);
    const instantiated = await WebAssembly.instantiate(bytes, { env: {} });
    return instantiated.instance;
  })();

  return wasmInstancePromise;
}

async function loadAdapter() {
  if (adapterPromise) return adapterPromise;

  adapterPromise = (async () => {
    const shim = resolveShimAdapter();
    if (shim) return shim;

    const compiled = await resolveCompiledModuleAdapter();
    if (compiled) return compiled;

    const instance = await loadWasmInstance();
    return resolveWasmAdapter(instance);
  })();

  return adapterPromise;
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

async function invokeRuntime(request, env, ctx) {
  const adapter = await loadAdapter();
  const payload = await encodeRequest(request, env, ctx);
  const payloadText = JSON.stringify(payload);

  const rawResult = await adapter.handle(payloadText);
  const decoded =
    typeof rawResult === "string"
      ? JSON.parse(rawResult)
      : rawResult && typeof rawResult === "object"
        ? rawResult
        : null;

  if (!decoded) {
    throw new Error("Runtime returned an empty or unsupported payload value.");
  }

  return decodeResponsePayload(decoded);
}

export default {
  async fetch(request, env, ctx) {
    try {
      return await invokeRuntime(request, env, ctx);
    } catch (error) {
      if (!adapterPromise || !wasmInstancePromise) {
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
};
