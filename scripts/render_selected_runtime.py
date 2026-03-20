#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path


def read_compile_target(config_path: Path | None, override: str) -> str:
    if override:
        return override
    if config_path and config_path.exists():
        config = json.loads(config_path.read_text())
        value = config.get("compile_target")
        if isinstance(value, str) and value:
            return value
    return "js"


def ensure_clean_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def write_keep_file(path: Path) -> None:
    (path / ".keep").write_text("selected-runtime-placeholder\n")


def copy_tree_contents(src: Path, dst: Path) -> None:
    ensure_clean_dir(dst)
    if not src.exists():
        return
    for child in src.iterdir():
        target = dst / child.name
        if child.is_dir():
            shutil.copytree(child, target)
        else:
            shutil.copy2(child, target)


def write_manifest(output_path: Path, runtime_kind: str) -> None:
    manifest = {
        "abi_version": 1,
        "app_id": "thunder-app",
        "runtime_kind": runtime_kind,
        "runtime_entry": "../../worker_runtime/index.mjs",
        "app_abi": "../../worker_runtime/app_abi.mjs",
        "compiled_runtime_backend": "../../worker_runtime/compiled_runtime_backend.mjs",
        "compiled_runtime": "thunder_runtime.mjs",
    }
    if runtime_kind == "wasm":
        manifest["generated_wasm_assets"] = "../../worker_runtime/generated_wasm_assets.mjs"
        manifest["bootstrap_module"] = "../../worker_runtime/compiled_runtime_bootstrap.mjs"
        manifest["assets_dir"] = "thunder_runtime.assets"
    output_path.write_text(json.dumps(manifest, indent=2) + "\n")


def main() -> int:
    if len(sys.argv) != 9:
        raise SystemExit(
            "usage: render_selected_runtime.py <config-path-or-dash> <compile-target-override> <js-runtime-src> <wasm-runtime-src> <wasm-assets-src> <runtime-out> <assets-dir-out> <manifest-out>"
        )

    (
        config_arg,
        override,
        js_runtime_arg,
        wasm_runtime_arg,
        wasm_assets_arg,
        runtime_out_arg,
        assets_out_arg,
        manifest_out_arg,
    ) = sys.argv[1:]
    config_path = None if config_arg == "-" else Path(config_arg)
    target = read_compile_target(config_path, override)
    if target not in {"js", "wasm"}:
        raise SystemExit(f"unsupported compile target: {target}")

    js_runtime = Path(js_runtime_arg)
    wasm_runtime = Path(wasm_runtime_arg)
    wasm_assets = Path(wasm_assets_arg)
    runtime_out = Path(runtime_out_arg)
    assets_out = Path(assets_out_arg)
    manifest_out = Path(manifest_out_arg)

    runtime_out.parent.mkdir(parents=True, exist_ok=True)
    manifest_out.parent.mkdir(parents=True, exist_ok=True)

    selected_runtime = js_runtime if target == "js" else wasm_runtime
    shutil.copy2(selected_runtime, runtime_out)
    if target == "wasm":
        copy_tree_contents(wasm_assets, assets_out)
    else:
        ensure_clean_dir(assets_out)
        write_keep_file(assets_out)
    write_manifest(manifest_out, target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
