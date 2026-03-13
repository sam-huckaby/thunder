const COMPILED_RUNTIME_RELATIVE_PATH = "../dist/worker/thunder_runtime.mjs";
const FALLBACK_CURRENT_SCRIPT_SRC =
  "https://thunder.invalid/dist/worker/thunder_runtime.mjs";

function resolveRelativeModuleUrl(relativePath) {
  try {
    const baseUrl = import.meta?.url;
    if (typeof baseUrl !== "string" || baseUrl === "") return null;
    return new URL(relativePath, baseUrl);
  } catch (_error) {
    return null;
  }
}

const compiledRuntimeSrc =
  resolveRelativeModuleUrl(COMPILED_RUNTIME_RELATIVE_PATH)?.toString() ??
  FALLBACK_CURRENT_SCRIPT_SRC;

const existingDocument = globalThis.document;
const existingCurrentScript = existingDocument?.currentScript;
const isNodeProcess = Boolean(globalThis.process?.versions?.node);
const shouldSkipBootstrap = globalThis.__THUNDER_SKIP_BOOTSTRAP__ === true;

let compiledRuntimeInitError = null;

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

if (!isNodeProcess && !shouldSkipBootstrap) {
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

    await import("../dist/worker/thunder_runtime.mjs");
    if (!(await waitForGlobalHandler())) {
      compiledRuntimeInitError = new Error(
        "Compiled runtime module loaded but did not register thunder_handle_json."
      );
    }
  } catch (error) {
    compiledRuntimeInitError = error;
  } finally {
    if (existingDocument) {
      existingDocument.currentScript = existingCurrentScript;
    } else {
      delete globalThis.document;
    }
  }
}

if (
  !compiledRuntimeInitError &&
  !isNodeProcess &&
  !shouldSkipBootstrap &&
  typeof globalThis.thunder_handle_json !== "function"
) {
  compiledRuntimeInitError = new Error(
    "Compiled runtime module loaded but did not register thunder_handle_json."
  );
}

export { compiledRuntimeInitError, waitForGlobalHandler };
