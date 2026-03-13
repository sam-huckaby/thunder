const COMPILED_RUNTIME_RELATIVE_PATH = "../dist/worker/thunder_runtime.mjs";
const FALLBACK_CURRENT_SCRIPT_SRC =
  "https://thunder.invalid/dist/worker/thunder_runtime.mjs";

let compiledRuntimeInitPromise = null;
let lastBootstrapState = {
  fetchedUrls: [],
  assignedType: null,
  finalType: null,
};
let bundledWasmAssetsModulePromise = null;

function resolveRelativeModuleUrl(relativePath) {
  try {
    const baseUrl = import.meta?.url;
    if (typeof baseUrl !== "string" || baseUrl === "") return null;
    return new URL(relativePath, baseUrl);
  } catch (_error) {
    return null;
  }
}

async function loadBundledWasmAssetsModule() {
  if (!bundledWasmAssetsModulePromise) {
    bundledWasmAssetsModulePromise = import("./generated_wasm_assets.mjs").catch(() => ({
      getBundledWasmAsset() {
        return null;
      },
      getBundledWasmModule() {
        return null;
      },
    }));
  }

  return bundledWasmAssetsModulePromise;
}

async function waitForGlobalHandler({ timeoutMs = 1500, intervalMs = 10 } = {}) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() <= deadline) {
    if (typeof globalThis.thunder_handle_json === "function") {
      return true;
    }
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
  return typeof globalThis.thunder_handle_json === "function";
}

function captureGlobalHandlerRegistration() {
  let assignedHandler = globalThis.thunder_handle_json;
  let resolveAssigned;
  const assigned = new Promise((resolve) => {
    resolveAssigned = resolve;
  });

  const existingDescriptor = Object.getOwnPropertyDescriptor(
    globalThis,
    "thunder_handle_json"
  );

  Object.defineProperty(globalThis, "thunder_handle_json", {
    configurable: true,
    enumerable: true,
    get() {
      return assignedHandler;
    },
    set(value) {
      assignedHandler = value;
      resolveAssigned(value);
    },
  });

  return {
    assigned,
    restore() {
      lastBootstrapState.assignedType = typeof assignedHandler;
      if (existingDescriptor) {
        Object.defineProperty(globalThis, "thunder_handle_json", existingDescriptor);
      } else if (assignedHandler === undefined) {
        delete globalThis.thunder_handle_json;
      } else {
        globalThis.thunder_handle_json = assignedHandler;
      }
      lastBootstrapState.finalType = typeof globalThis.thunder_handle_json;
    },
  };
}

function captureRuntimeErrors() {
  let cleanup = () => {};
  const errorPromise = new Promise((_, reject) => {
    const onUnhandledRejection = (event) => {
      reject(event?.reason ?? new Error("Compiled runtime rejected during initialization."));
    };
    const onError = (event) => {
      reject(event?.error ?? new Error(event?.message ?? "Compiled runtime errored during initialization."));
    };

    if (typeof globalThis.addEventListener === "function") {
      globalThis.addEventListener("unhandledrejection", onUnhandledRejection);
      globalThis.addEventListener("error", onError);
      cleanup = () => {
        globalThis.removeEventListener("unhandledrejection", onUnhandledRejection);
        globalThis.removeEventListener("error", onError);
      };
    }
  });

  return { errorPromise, cleanup };
}

async function initializeCompiledRuntime({ timeoutMs = 1500, intervalMs = 10 } = {}) {
  if (globalThis.__THUNDER_SKIP_BOOTSTRAP__ === true) {
    return { initialized: false, skipped: true };
  }

  if (typeof globalThis.thunder_handle_json === "function") {
    return { initialized: true, skipped: false };
  }

  if (!compiledRuntimeInitPromise) {
    compiledRuntimeInitPromise = (async () => {
      const compiledRuntimeSrc =
        resolveRelativeModuleUrl(COMPILED_RUNTIME_RELATIVE_PATH)?.toString() ??
        FALLBACK_CURRENT_SCRIPT_SRC;

      const existingDocument = globalThis.document;
      const existingCurrentScript = existingDocument?.currentScript;
      const existingFetch = globalThis.fetch;
      const existingProcess = globalThis.process;
      const existingInstantiateStreaming = WebAssembly.instantiateStreaming;
      const fetchedUrls = [];
      lastBootstrapState = {
        fetchedUrls,
        assignedType: null,
        finalType: null,
      };
      const registration = captureGlobalHandlerRegistration();
      const runtimeErrors = captureRuntimeErrors();
      const bundledWasmAssets = await loadBundledWasmAssetsModule();

      try {
        if (!globalThis.document) {
          globalThis.document = {
            currentScript: { src: compiledRuntimeSrc },
          };
        } else {
          globalThis.document.currentScript = {
            src: compiledRuntimeSrc,
          };
        }

        globalThis.process = undefined;

        if (typeof WebAssembly.instantiateStreaming !== "function") {
          WebAssembly.instantiateStreaming = async (responsePromise, imports, options) => {
            const response = await responsePromise;
            if (response?.__thunder_wasm_module) {
              const instantiated = await WebAssembly.instantiate(
                response.__thunder_wasm_module,
                imports,
                options
              );
              return instantiated instanceof WebAssembly.Instance
                ? { module: response.__thunder_wasm_module, instance: instantiated }
                : instantiated;
            }
            const bytes = await response.arrayBuffer();
            return WebAssembly.instantiate(bytes, imports, options);
          };
        }

        if (typeof existingFetch === "function") {
          globalThis.fetch = async (...args) => {
            const [resource] = args;
            const requestUrl =
              resource instanceof Request ? resource.url : String(resource);
            fetchedUrls.push(requestUrl);
            const bundled = bundledWasmAssets.getBundledWasmAsset(requestUrl);
            const bundledModule = bundledWasmAssets.getBundledWasmModule(requestUrl);
            if (bundled) {
              return {
                ok: true,
                status: 200,
                __thunder_wasm_module: bundledModule,
                async arrayBuffer() {
                  return bundled.buffer.slice(
                    bundled.byteOffset,
                    bundled.byteOffset + bundled.byteLength
                  );
                },
              };
            }
            return existingFetch(...args);
          };
        }

        await import("../dist/worker/thunder_runtime.mjs");
        const handlerRegistered = await Promise.race([
          registration.assigned.then(() => true),
          runtimeErrors.errorPromise,
          waitForGlobalHandler({ timeoutMs, intervalMs }),
        ]);
        if (!handlerRegistered) {
          throw new Error(
            "Compiled runtime module loaded but did not register thunder_handle_json. Fetches observed during init: " +
              (fetchedUrls.length > 0 ? fetchedUrls.join(", ") : "none")
          );
        }
        return { initialized: true, skipped: false };
      } finally {
        if (typeof existingFetch === "function") {
          globalThis.fetch = existingFetch;
        }
        globalThis.process = existingProcess;
        WebAssembly.instantiateStreaming = existingInstantiateStreaming;
        runtimeErrors.cleanup();
        registration.restore();
        if (existingDocument) {
          existingDocument.currentScript = existingCurrentScript;
        } else {
          delete globalThis.document;
        }
      }
    })();
  }

  return compiledRuntimeInitPromise;
}

function resetCompiledRuntimeBootstrapForTests() {
  compiledRuntimeInitPromise = null;
  bundledWasmAssetsModulePromise = null;
  lastBootstrapState = { fetchedUrls: [], assignedType: null, finalType: null };
}

function getCompiledRuntimeBootstrapState() {
  return {
    fetchedUrls: [...lastBootstrapState.fetchedUrls],
    assignedType: lastBootstrapState.assignedType,
    finalType: lastBootstrapState.finalType,
  };
}

export {
  getCompiledRuntimeBootstrapState,
  initializeCompiledRuntime,
  resetCompiledRuntimeBootstrapForTests,
  resolveRelativeModuleUrl,
  waitForGlobalHandler,
};
