#!/usr/bin/env python3
from __future__ import annotations

import base64
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: generate_wasm_asset_map.py <assets_dir> <output_path>")

    assets_dir = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    entries = []
    for wasm_path in sorted(assets_dir.glob("*.wasm")):
        encoded = base64.b64encode(wasm_path.read_bytes()).decode("ascii")
        entries.append((wasm_path.name, encoded))

    lines = [
        "const IS_NODE_RUNTIME = globalThis.__THUNDER_SKIP_BOOTSTRAP__ === true;",
        "const WASM_ASSET_BASE64 = new Map([",
    ]
    for name, encoded in entries:
        lines.append(f'  ["{name}", "{encoded}"],')
    lines.extend(
        [
            "]);",
            "",
            "const WASM_MODULE_LOADERS = [",
        ]
    )
    for name, _encoded in entries:
        lines.append(
            f'  ["{name}", async () => import("../dist/worker/thunder_runtime.assets/{name}")],'
        )
    lines.extend(
        [
            "];",
            "",
            "function normalizeAssetKey(path) {",
            "  const value = String(path);",
            "  const parts = value.split('/');",
            "  return parts[parts.length - 1];",
            "}",
            "",
            "function base64ToBytes(value) {",
            "  const binary = atob(value);",
            "  const bytes = new Uint8Array(binary.length);",
            "  for (let i = 0; i < binary.length; i += 1) {",
            "    bytes[i] = binary.charCodeAt(i);",
            "  }",
            "  return bytes;",
            "}",
            "",
            "const WASM_MODULES = new Map();",
            "",
            "if (!IS_NODE_RUNTIME) {",
            "  for (const [name, loadModule] of WASM_MODULE_LOADERS) {",
            "    const module = await loadModule();",
            "    WASM_MODULES.set(name, module.default ?? module);",
            "  }",
            "}",
            "",
            "export function getBundledWasmAsset(path) {",
            "  const encoded = WASM_ASSET_BASE64.get(normalizeAssetKey(path));",
            "  return encoded ? base64ToBytes(encoded) : null;",
            "}",
            "",
            "export function getBundledWasmModule(path) {",
            "  return WASM_MODULES.get(normalizeAssetKey(path)) ?? null;",
            "}",
            "",
            "export function listBundledWasmAssets() {",
            "  return [...WASM_ASSET_BASE64.keys()];",
            "}",
        ]
    )

    output_path.write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
