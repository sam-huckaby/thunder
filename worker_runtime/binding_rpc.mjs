import { getRequestContextStore } from "./request_context.mjs";

const ALLOWED_OPS = new Set([
  "kv.get",
  "kv.put",
  "kv.delete",
  "r2.get",
  "r2.put",
  "d1.query",
  "ai.run",
  "queue.send",
  "queue.send_batch",
  "service.fetch",
  "durable_object.call",
  "binding.invoke",
]);

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

function requireStore(requestId) {
  const store = getRequestContextStore(requestId);
  if (!store) {
    throw new Error("Thunder binding RPC called without an active request context.");
  }
  return store;
}

function validateArgs(args) {
  if (args === null || args === undefined) return {};
  if (typeof args !== "object" || Array.isArray(args)) {
    throw new Error("Thunder binding RPC args must be an object when provided.");
  }
  return args;
}

function requireString(value, field) {
  if (typeof value !== "string" || value === "") {
    throw new Error(`Thunder binding RPC field '${field}' must be a non-empty string.`);
  }
  return value;
}

function resolveBinding(env, binding, expectedMethod) {
  const value = env?.[binding];
  if (!value || typeof value[expectedMethod] !== "function") {
    throw new Error(
      `Thunder binding RPC binding '${binding}' does not support '${expectedMethod}'.`
    );
  }
  return value;
}

function ok(result = {}) {
  return { ok: true, ...result };
}

function errorResult(message, code = "binding_rpc_error") {
  return {
    ok: false,
    error: {
      code,
      message,
    },
  };
}

function parseJson(value, field) {
  try {
    return JSON.parse(value);
  } catch (error) {
    throw new Error(`Thunder binding RPC field '${field}' must be valid JSON.`);
  }
}

function stringifyJson(value) {
  return JSON.stringify(value ?? null);
}

async function handleKvGet(env, args) {
  const binding = requireString(args.binding, "binding");
  const key = requireString(args.key, "key");
  const type = args.type === "bytes" ? "arrayBuffer" : "text";
  const namespace = resolveBinding(env, binding, "get");
  const value = await namespace.get(key, { type });

  if (value === null) return ok({ value: null });
  if (type === "arrayBuffer") {
    return ok({ value_base64: bytesToBase64(new Uint8Array(value)) });
  }
  return ok({ value });
}

async function handleKvPut(env, args) {
  const binding = requireString(args.binding, "binding");
  const key = requireString(args.key, "key");
  const namespace = resolveBinding(env, binding, "put");

  let value;
  if (typeof args.value_base64 === "string") {
    value = base64ToBytes(args.value_base64);
  } else {
    value = requireString(args.value, "value");
  }

  await namespace.put(key, value);
  return ok();
}

async function handleKvDelete(env, args) {
  const binding = requireString(args.binding, "binding");
  const key = requireString(args.key, "key");
  const namespace = resolveBinding(env, binding, "delete");
  await namespace.delete(key);
  return ok();
}

async function handleR2Get(env, args) {
  const binding = requireString(args.binding, "binding");
  const key = requireString(args.key, "key");
  const type = args.type === "bytes" ? "bytes" : "text";
  const bucket = resolveBinding(env, binding, "get");
  const object = await bucket.get(key);
  if (object === null) return ok({ value: null });
  if (type === "bytes") {
    const bytes = new Uint8Array(await object.arrayBuffer());
    return ok({ value_base64: bytesToBase64(bytes) });
  }
  return ok({ value: await object.text() });
}

async function handleR2Put(env, args) {
  const binding = requireString(args.binding, "binding");
  const key = requireString(args.key, "key");
  const bucket = resolveBinding(env, binding, "put");
  const value =
    typeof args.value_base64 === "string"
      ? base64ToBytes(args.value_base64)
      : requireString(args.value, "value");
  await bucket.put(key, value);
  return ok();
}

async function handleD1Query(env, args) {
  const binding = requireString(args.binding, "binding");
  const sql = requireString(args.sql, "sql");
  const action = requireString(args.action, "action");
  const db = resolveBinding(env, binding, "prepare");
  let statement = db.prepare(sql);

  if (typeof args.params_json === "string") {
    const params = parseJson(args.params_json, "params_json");
    if (!Array.isArray(params)) {
      throw new Error("Thunder binding RPC field 'params_json' must decode to a JSON array.");
    }
    if (typeof statement.bind === "function") {
      statement = statement.bind(...params);
    }
  }

  if (!statement || typeof statement[action] !== "function") {
    throw new Error(`Thunder D1 statement does not support action '${action}'.`);
  }

  const value = await statement[action]();
  return ok({ value_json: stringifyJson(value) });
}

async function handleAiRun(env, args) {
  const binding = requireString(args.binding, "binding");
  const model = requireString(args.model, "model");
  const ai = resolveBinding(env, binding, "run");
  const inputJson = requireString(args.input_json, "input_json");
  const input = parseJson(inputJson, "input_json");
  const options =
    typeof args.options_json === "string"
      ? parseJson(args.options_json, "options_json")
      : undefined;
  const value = await ai.run(model, input, options);
  return ok({ value_json: stringifyJson(value) });
}

async function handleQueueSend(env, args) {
  const binding = requireString(args.binding, "binding");
  const queue = resolveBinding(env, binding, "send");
  let value;
  if (typeof args.value_base64 === "string") {
    value = base64ToBytes(args.value_base64);
  } else if (typeof args.value_json === "string") {
    value = parseJson(args.value_json, "value_json");
  } else {
    value = requireString(args.value, "value");
  }
  await queue.send(value);
  return ok();
}

async function handleQueueSendBatch(env, args) {
  const binding = requireString(args.binding, "binding");
  const queue = resolveBinding(env, binding, "sendBatch");
  const messagesJson = requireString(args.messages_json, "messages_json");
  const messages = parseJson(messagesJson, "messages_json");
  if (!Array.isArray(messages)) {
    throw new Error("Thunder binding RPC field 'messages_json' must decode to a JSON array.");
  }
  await queue.sendBatch(messages);
  return ok();
}

async function handleServiceFetch(env, args) {
  const binding = requireString(args.binding, "binding");
  const service = resolveBinding(env, binding, "fetch");
  const url = requireString(args.url, "url");
  const init =
    typeof args.init_json === "string" ? parseJson(args.init_json, "init_json") : undefined;
  const response = await service.fetch(url, init);
  const text = await response.text();
  return ok({
    value_json: stringifyJson({
      status: response.status,
      body_text: text,
    }),
  });
}

async function handleDurableObjectCall(env, args) {
  const binding = requireString(args.binding, "binding");
  const name = requireString(args.name, "name");
  const method = requireString(args.method, "method");
  const namespace = resolveBinding(env, binding, "getByName");
  const stub = namespace.getByName(name);
  if (!stub || typeof stub[method] !== "function") {
    throw new Error(
      `Thunder Durable Object stub for '${binding}' does not support method '${method}'.`
    );
  }
  const argsJson = requireString(args.args_json, "args_json");
  const methodArgs = parseJson(argsJson, "args_json");
  if (!Array.isArray(methodArgs)) {
    throw new Error("Thunder binding RPC field 'args_json' must decode to a JSON array.");
  }
  const value = await stub[method](...methodArgs);
  return ok({ value_json: stringifyJson(value) });
}

async function handleBindingInvoke(env, args) {
  const binding = requireString(args.binding, "binding");
  const method = requireString(args.method, "method");
  const argsJson = requireString(args.args_json, "args_json");
  const bindingValue = resolveBinding(env, binding, method);
  const methodArgs = parseJson(argsJson, "args_json");

  if (!Array.isArray(methodArgs)) {
    throw new Error("Thunder binding RPC field 'args_json' must decode to a JSON array.");
  }

  const value = await bindingValue[method](...methodArgs);
  return ok({ value_json: stringifyJson(value) });
}

async function dispatchOp(store, op, args) {
  switch (op) {
    case "kv.get":
      return handleKvGet(store.env, args);
    case "kv.put":
      return handleKvPut(store.env, args);
    case "kv.delete":
      return handleKvDelete(store.env, args);
    case "r2.get":
      return handleR2Get(store.env, args);
    case "r2.put":
      return handleR2Put(store.env, args);
    case "d1.query":
      return handleD1Query(store.env, args);
    case "ai.run":
      return handleAiRun(store.env, args);
    case "queue.send":
      return handleQueueSend(store.env, args);
    case "queue.send_batch":
      return handleQueueSendBatch(store.env, args);
    case "service.fetch":
      return handleServiceFetch(store.env, args);
    case "durable_object.call":
      return handleDurableObjectCall(store.env, args);
    case "binding.invoke":
      return handleBindingInvoke(store.env, args);
    default:
      throw new Error(`Unimplemented Thunder binding RPC op: ${op}`);
  }
}

globalThis.__thunder_binding_rpc = async (requestId, op, args) => {
  let store;
  let normalizedArgs;

  try {
    store = requireStore(requestId);
    normalizedArgs = validateArgs(args);

    if (typeof op !== "string" || !ALLOWED_OPS.has(op)) {
      throw new Error(`Unsupported Thunder binding RPC op: ${String(op)}`);
    }
  } catch (error) {
    return errorResult(
      error instanceof Error ? error.message : String(error),
      "binding_rpc_invalid_request"
    );
  }

  try {
    return await dispatchOp(store, op, normalizedArgs);
  } catch (error) {
    return errorResult(
      error instanceof Error ? error.message : String(error),
      "binding_rpc_operation_failed"
    );
  }
};

export const __internal = {
  ALLOWED_OPS,
  bytesToBase64,
  base64ToBytes,
  ok,
  errorResult,
  requireStore,
  validateArgs,
  requireString,
  resolveBinding,
  handleKvGet,
  handleKvPut,
  handleKvDelete,
  handleR2Get,
  handleR2Put,
  handleD1Query,
  handleAiRun,
  handleQueueSend,
  handleQueueSendBatch,
  handleServiceFetch,
  handleDurableObjectCall,
  handleBindingInvoke,
  parseJson,
  stringifyJson,
  dispatchOp,
};
