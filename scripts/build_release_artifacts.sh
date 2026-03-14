#!/usr/bin/env bash
set -eu

usage() {
  cat <<'EOF'
Usage:
  bash scripts/build_release_artifacts.sh binary
  bash scripts/build_release_artifacts.sh framework
  bash scripts/build_release_artifacts.sh checksums

Environment:
  THUNDER_ARTIFACTS_DIR   Output directory. Default: <repo>/artifacts
  THUNDER_VERSION         Override version. Default: package.json version
  THUNDER_RELEASE_OS      Required for binary mode. Example: darwin
  THUNDER_RELEASE_ARCH    Required for binary mode. Example: arm64
  THUNDER_BINARY_SOURCE   Override built CLI path
EOF
}

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
artifacts_dir="${THUNDER_ARTIFACTS_DIR:-$repo_root/artifacts}"
command="${1:-}"

require_path() {
  if [ ! -e "$1" ]; then
    echo "Missing required path: $1" >&2
    exit 1
  fi
}

version_from_repo() {
  python3 - <<'PY' "$repo_root/package.json" "$repo_root/packages/thunder_cli/version.ml"
from pathlib import Path
import json
import re
import sys

package_json = json.loads(Path(sys.argv[1]).read_text())
version_ml = Path(sys.argv[2]).read_text()
package_version = package_json.get("version", "0.1.0")
match = re.search(r'"([^"]+)"', version_ml)
if match is None:
    raise SystemExit("Could not parse CLI version from packages/thunder_cli/version.ml")
cli_version = match.group(1)
if package_version != cli_version:
    raise SystemExit(
        f"Version mismatch: package.json has {package_version} but packages/thunder_cli/version.ml has {cli_version}"
    )
print(package_version)
PY
}

version="${THUNDER_VERSION:-$(version_from_repo)}"
version="${version#v}"

binary_mode() {
  os_name="${THUNDER_RELEASE_OS:-}"
  arch_name="${THUNDER_RELEASE_ARCH:-}"
  binary_source="${THUNDER_BINARY_SOURCE:-$repo_root/_build/default/packages/thunder_cli/main.exe}"

  if [ -z "$os_name" ] || [ -z "$arch_name" ]; then
    echo "THUNDER_RELEASE_OS and THUNDER_RELEASE_ARCH are required for binary mode" >&2
    exit 1
  fi

  require_path "$binary_source"
  mkdir -p "$artifacts_dir"
  cp "$binary_source" "$artifacts_dir/thunder-$version-$os_name-$arch_name"
  chmod +x "$artifacts_dir/thunder-$version-$os_name-$arch_name"
}

framework_mode() {
  require_path "$repo_root/dune-project"
  require_path "$repo_root/packages"
  require_path "$repo_root/worker_runtime"
  require_path "$repo_root/scripts"

  staging_dir="$(mktemp -d)"
  trap 'rm -rf "$staging_dir"' EXIT INT TERM

  mkdir -p "$artifacts_dir"
  cp "$repo_root/dune-project" "$staging_dir/dune-project"
  cp -R "$repo_root/packages" "$staging_dir/packages"
  cp -R "$repo_root/worker_runtime" "$staging_dir/worker_runtime"
  cp -R "$repo_root/scripts" "$staging_dir/scripts"
  rm -f "$staging_dir/worker_runtime/generated_wasm_assets.mjs"

  tar -czf "$artifacts_dir/thunder-framework-$version.tar.gz" -C "$staging_dir" .
}

checksums_mode() {
  mkdir -p "$artifacts_dir"
  (
    cd "$artifacts_dir"
    rm -f checksums.txt
    if command -v shasum >/dev/null 2>&1; then
      shasum -a 256 thunder-* > checksums.txt
    elif command -v sha256sum >/dev/null 2>&1; then
      sha256sum thunder-* > checksums.txt
    else
      echo "Need shasum or sha256sum to write checksums" >&2
      exit 1
    fi
  )
}

case "$command" in
  binary) binary_mode ;;
  framework) framework_mode ;;
  checksums) checksums_mode ;;
  *)
    usage >&2
    exit 2
    ;;
esac
