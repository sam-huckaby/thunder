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

let compiledRuntimeInitError = null;

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
} catch (error) {
  compiledRuntimeInitError = error;
} finally {
  if (existingDocument) {
    existingDocument.currentScript = existingCurrentScript;
  } else {
    delete globalThis.document;
  }
}

if (!compiledRuntimeInitError && typeof globalThis.thunder_handle_json !== "function") {
  compiledRuntimeInitError = new Error(
    "Compiled runtime module loaded but did not register thunder_handle_json."
  );
}

export { compiledRuntimeInitError };
