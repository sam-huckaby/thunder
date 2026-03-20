import {
  getCompiledRuntimeBootstrapState,
  initializeCompiledRuntime,
  resetCompiledRuntimeBootstrapForTests,
} from "./compiled_runtime_bootstrap.mjs";

let initialized = false;
let bundledWasmAssetsModulePromise = null;

async function loadBundledWasmAssetsModule() {
  if (!bundledWasmAssetsModulePromise) {
    bundledWasmAssetsModulePromise = import("./generated_wasm_assets.mjs").catch(() => ({
      getBundledWasmAsset() {
        return null;
      },
    }));
  }

  return bundledWasmAssetsModulePromise;
}

export async function initCompiledRuntimeBackend() {
  const originalRequire = typeof require === "function" ? require : null;
  const bundledWasmAssets = await loadBundledWasmAssetsModule();
  if (originalRequire) {
    const shimmedRequire = (specifier) => {
      if (specifier === "node:fs/promises") {
        const module = originalRequire(specifier);
        return {
          ...module,
          async readFile(path, ...rest) {
            const bundled = bundledWasmAssets.getBundledWasmAsset(path);
            if (bundled) {
              return bundled;
            }
            return module.readFile(path, ...rest);
          },
        };
      }
      return originalRequire(specifier);
    };
    Object.assign(shimmedRequire, originalRequire);
    shimmedRequire.main = originalRequire.main;
    globalThis.require = shimmedRequire;
  }

  await initializeCompiledRuntime();

  if (typeof globalThis.thunder_handle_json !== "function") {
    const state = getCompiledRuntimeBootstrapState();
    throw new Error(
      "Compiled runtime module loaded but did not register thunder_handle_json." +
        ` assignedType=${state.assignedType} finalType=${state.finalType} fetches=${state.fetchedUrls.join(",") || "none"}`
    );
  }

  initialized = true;
  return {
    kind: "compiled-wasm-runtime",
  };
}

export async function handleCompiledRuntimePayload(jsonPayload) {
  if (!initialized) {
    await initCompiledRuntimeBackend();
  }
  return globalThis.thunder_handle_json(jsonPayload);
}

export function resetCompiledRuntimeBackendForTests() {
  initialized = false;
  bundledWasmAssetsModulePromise = null;
  resetCompiledRuntimeBootstrapForTests();
}
