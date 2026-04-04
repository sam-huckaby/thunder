const manifestModule = await import("../dist/worker/manifest.json", {
  with: { type: "json" },
}).catch(() => import("./development_manifest.mjs"));
const manifest = manifestModule.default;
import {
  handleCompiledJsRuntimePayload,
  initCompiledJsRuntimeBackend,
  resetCompiledJsRuntimeBackendForTests,
} from "./compiled_js_runtime_backend.mjs";
import {
  initCompiledRuntimeBackend,
  handleCompiledRuntimePayload,
  resetCompiledRuntimeBackendForTests,
} from "./compiled_runtime_backend.mjs";

let initializedStatePromise = null;
let runtimeInitialized = false;

export const THUNDER_ABI_JSON_VERSION = 1;
export const THUNDER_ABI_INIT_CAPABILITIES = [
  "json_request_payload",
  "json_response_payload",
  "buffered_body",
  "env_bindings",
  "ctx_features",
  "async_handlers",
  "request_context_raw_env",
  "request_context_raw_ctx",
  "binding_rpc",
  "binary_response_payload",
];

const REQUEST_CONTEXT_STRATEGIES = ["auto", "als", "map"];

function resolveRelativeModuleUrl(relativePath) {
  try {
    const baseUrl = import.meta?.url;
    if (typeof baseUrl !== "string" || baseUrl === "") return null;
    return new URL(relativePath, baseUrl);
  } catch (_error) {
    return null;
  }
}

function defaultAssetBaseUrl() {
  if (typeof manifest.assets_dir !== "string" || manifest.assets_dir === "") {
    return null;
  }
  const manifestDir = resolveRelativeModuleUrl("../dist/worker/");
  if (!manifestDir) return null;
  try {
    return new URL(`${manifest.assets_dir}/`, manifestDir).toString();
  } catch (_error) {
    return manifestDir.toString();
  }
}

function normalizeInitPayload(initPayload = {}) {
  return {
    abi_version:
      typeof initPayload.abi_version === "number"
        ? initPayload.abi_version
        : typeof manifest.abi_version === "number"
          ? manifest.abi_version
          : THUNDER_ABI_JSON_VERSION,
    asset_base_url:
      typeof initPayload.asset_base_url === "string"
        ? initPayload.asset_base_url
        : defaultAssetBaseUrl(),
    app_id:
      typeof initPayload.app_id === "string"
        ? initPayload.app_id
        : typeof manifest.app_id === "string"
          ? manifest.app_id
          : "thunder-app",
    expected_capabilities: Array.isArray(initPayload.expected_capabilities)
      ? initPayload.expected_capabilities.filter((value) => typeof value === "string")
      : [],
    request_context_strategy: REQUEST_CONTEXT_STRATEGIES.includes(
      initPayload.request_context_strategy
    )
      ? initPayload.request_context_strategy
      : "auto",
  };
}

function makeInitResult(initPayload, backendKind) {
  return {
    abi_version: THUNDER_ABI_JSON_VERSION,
    app_id: initPayload.app_id,
    asset_base_url: initPayload.asset_base_url,
    capabilities: [...THUNDER_ABI_INIT_CAPABILITIES],
    request_context_strategy: initPayload.request_context_strategy,
    backend_kind: backendKind,
  };
}

function validateExpectedCapabilities(initPayload) {
  const unsupported = initPayload.expected_capabilities.filter(
    (capability) => !THUNDER_ABI_INIT_CAPABILITIES.includes(capability)
  );

  if (unsupported.length > 0) {
    throw new Error(
      `Thunder ABI init is missing required capabilities: ${unsupported.join(", ")}`
    );
  }
}

function resolveOverrideBackend() {
  const shim = globalThis.__THUNDER_WASM_SHIM__;
  if (!shim || typeof shim.handle !== "function") return null;
  return {
    kind: "shim-override",
    async init() {
      return { kind: "shim-override" };
    },
    async handle(jsonPayload) {
      return shim.handle(jsonPayload);
    },
  };
}

function resolveManifestRuntimeKind() {
  return manifest.runtime_kind === "js" ? "js" : "wasm";
}

function resolveRuntimeBackend(runtimeKind = resolveManifestRuntimeKind()) {
  const overrideBackend = resolveOverrideBackend();
  if (overrideBackend) return overrideBackend;

  if (runtimeKind === "js") {
    return {
      kind: "compiled-js-runtime",
      init: initCompiledJsRuntimeBackend,
      handle: handleCompiledJsRuntimePayload,
    };
  }

  return {
    kind: "compiled-wasm-runtime",
    init: initCompiledRuntimeBackend,
    handle: handleCompiledRuntimePayload,
  };
}

async function getInitializedState({ initPayload }) {
  const normalizedPayload = normalizeInitPayload(initPayload);
  if (normalizedPayload.abi_version !== THUNDER_ABI_JSON_VERSION) {
    throw new Error(
      `Unsupported Thunder ABI version: ${normalizedPayload.abi_version}`
    );
  }
  validateExpectedCapabilities(normalizedPayload);

  if (!initializedStatePromise) {
    initializedStatePromise = (async () => {
      const backend = resolveRuntimeBackend();
        await backend.init();
        runtimeInitialized = true;
        return {
          backend,
          init_result: makeInitResult(normalizedPayload, backend.kind),
        };
      })();
  }

  return initializedStatePromise;
}

export async function init({ initPayload = {} } = {}) {
  const state = await getInitializedState({ initPayload });
  return state.init_result;
}

export async function handle({
  request,
  env,
  ctx,
  initPayload = {},
  encodeRequest,
  decodeResponsePayload,
}) {
  const state = await getInitializedState({ initPayload });
  const payload = await encodeRequest(request, env, ctx);
  const rawResult = await state.backend.handle(JSON.stringify(payload));
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

export function isRuntimeInitialized() {
  return runtimeInitialized;
}

export function resetForTests() {
  initializedStatePromise = null;
  runtimeInitialized = false;
  resetCompiledJsRuntimeBackendForTests();
  resetCompiledRuntimeBackendForTests();
}

export const __internal = {
  manifest,
  REQUEST_CONTEXT_STRATEGIES,
  resolveRelativeModuleUrl,
  defaultAssetBaseUrl,
  normalizeInitPayload,
  makeInitResult,
  validateExpectedCapabilities,
  resolveManifestRuntimeKind,
  resolveOverrideBackend,
  resolveRuntimeBackend,
};
