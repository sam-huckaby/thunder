let initialized = false;
let initPromise = null;

export async function initCompiledJsRuntimeBackend() {
  if (typeof globalThis.thunder_handle_json === "function") {
    initialized = true;
    return { kind: "compiled-js-runtime" };
  }

  if (!initPromise) {
    initPromise = (async () => {
      await import("../dist/worker/thunder_runtime.mjs");
      if (typeof globalThis.thunder_handle_json !== "function") {
        throw new Error(
          "Compiled JS runtime module loaded but did not register thunder_handle_json."
        );
      }
      initialized = true;
      return { kind: "compiled-js-runtime" };
    })();
  }

  return initPromise;
}

export async function handleCompiledJsRuntimePayload(jsonPayload) {
  if (!initialized) {
    await initCompiledJsRuntimeBackend();
  }
  return globalThis.thunder_handle_json(jsonPayload);
}

export function resetCompiledJsRuntimeBackendForTests() {
  initialized = false;
  initPromise = null;
}
