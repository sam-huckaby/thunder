const REQUEST_CONTEXT_STRATEGIES = ["auto", "als", "map"];

const asyncHooksModule = await import("node:async_hooks").catch(() => null);
const AsyncLocalStorageCtor = asyncHooksModule?.AsyncLocalStorage ?? null;

let asyncLocalStorage = AsyncLocalStorageCtor ? new AsyncLocalStorageCtor() : null;
let strategyOverride = null;
const requestContextMap = new Map();

function makeRequestId() {
  if (typeof crypto?.randomUUID === "function") {
    return crypto.randomUUID();
  }

  return `thunder-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function normalizeRequestedStrategy(value) {
  if (typeof value !== "string") return "auto";
  return REQUEST_CONTEXT_STRATEGIES.includes(value) ? value : "auto";
}

function canUseAls() {
  return asyncLocalStorage !== null;
}

export function getRequestContextStrategy(requestedStrategy = "auto") {
  const normalized = normalizeRequestedStrategy(strategyOverride ?? requestedStrategy);

  if (normalized === "map") return "map";
  if (normalized === "als") {
    if (!canUseAls()) {
      throw new Error(
        "Thunder request context strategy 'als' requires node:async_hooks AsyncLocalStorage support."
      );
    }
    return "als";
  }

  return canUseAls() ? "als" : "map";
}

export function enterRequestContext(env, ctx, options = {}) {
  const strategy = getRequestContextStrategy(options.strategy);
  const requestId = makeRequestId();
  const store = {
    env,
    ctx,
    requestId,
    caches: new Map(),
  };

  if (strategy === "als") {
    return {
      requestId,
      strategy,
      run(fn) {
        return asyncLocalStorage.run(store, fn);
      },
      exit() {},
    };
  }

  requestContextMap.set(requestId, store);
  return {
    requestId,
    strategy,
    run(fn) {
      return fn();
    },
    exit() {
      requestContextMap.delete(requestId);
    },
  };
}

export function getRequestContextStore(requestId) {
  const alsStore = asyncLocalStorage?.getStore();
  if (alsStore) return alsStore;
  if (typeof requestId === "string") return requestContextMap.get(requestId);
  return undefined;
}

globalThis.__thunder_get_env = (requestId) => getRequestContextStore(requestId)?.env ?? null;
globalThis.__thunder_get_ctx = (requestId) => getRequestContextStore(requestId)?.ctx ?? null;

function resetForTests() {
  requestContextMap.clear();
  strategyOverride = null;
  asyncLocalStorage = AsyncLocalStorageCtor ? new AsyncLocalStorageCtor() : null;
}

function setStrategyOverrideForTests(strategy) {
  strategyOverride = strategy === null ? null : normalizeRequestedStrategy(strategy);
}

export const __internal = {
  REQUEST_CONTEXT_STRATEGIES,
  normalizeRequestedStrategy,
  canUseAls,
  getRequestContextStore,
  requestContextMap,
  resetForTests,
  setStrategyOverrideForTests,
};
