#!/usr/bin/env bash
set -eu

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
bin_dir="${THUNDER_BIN_DIR:-$HOME/.local/bin}"
home_base="${THUNDER_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/thunder}"
shell_name="${SHELL##*/}"
release_repo="${THUNDER_RELEASE_REPO:-samhuckaby/thunder}"
release_api_base="${THUNDER_RELEASE_API_BASE:-https://api.github.com/repos/$release_repo/releases}"
asset_base_url="${THUNDER_ASSET_BASE_URL:-}"
asset_dir="${THUNDER_ASSET_DIR:-}"

path_contains_bin_dir=0
case ":${PATH:-}:" in
  *":$bin_dir:"*) path_contains_bin_dir=1 ;;
esac

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

trim_tag_prefix() {
  case "$1" in
    v*) printf '%s\n' "${1#v}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

release_tag_for_version() {
  case "$1" in
    v*) printf '%s\n' "$1" ;;
    *) printf 'v%s\n' "$1" ;;
  esac
}

platform_os() {
  case "$(uname -s)" in
    Darwin) printf 'darwin\n' ;;
    Linux) printf 'linux\n' ;;
    *)
      echo "Unsupported operating system: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

platform_arch() {
  case "$(uname -m)" in
    arm64|aarch64) printf 'arm64\n' ;;
    x86_64) printf 'x86_64\n' ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

repo_version() {
  python3 - <<'PY' "$repo_root/package.json"
from pathlib import Path
import json
import sys
data = json.loads(Path(sys.argv[1]).read_text())
print(data.get("version", "0.1.0"))
PY
}

ensure_release_version() {
  if [ -n "${THUNDER_VERSION:-}" ]; then
    trim_tag_prefix "$THUNDER_VERSION"
    return
  fi

  if [ -n "$asset_dir" ]; then
    echo "THUNDER_VERSION must be set when THUNDER_ASSET_DIR is used" >&2
    exit 1
  fi

  require_command curl
  require_command python3
  python3 - <<'PY' "$release_api_base" "${GITHUB_TOKEN:-}"
import json
import sys
import urllib.request

url = sys.argv[1] + "/latest"
token = sys.argv[2]
req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
if token:
    req.add_header("Authorization", f"Bearer {token}")
with urllib.request.urlopen(req) as response:
    payload = json.load(response)
print(payload["tag_name"].removeprefix("v"))
PY
}

local_install_available() {
  [ -f "$repo_root/dune-project" ] \
    && [ -d "$repo_root/packages" ] \
    && [ -d "$repo_root/worker_runtime" ] \
    && [ -d "$repo_root/scripts" ] \
    && [ -f "${THUNDER_BINARY_SOURCE:-$repo_root/_build/default/packages/thunder_cli/main.exe}" ]
}

download_file() {
  src="$1"
  dest="$2"
  if [ -n "$asset_dir" ]; then
    cp "$asset_dir/$src" "$dest"
  elif [ -n "$asset_base_url" ]; then
    curl -fsSL "$asset_base_url/$src" -o "$dest"
  else
    curl -fsSL "$src" -o "$dest"
  fi
}

verify_checksums() {
  checksums_path="$1"
  binary_name="$2"
  framework_name="$3"
  filtered_path="$(dirname "$checksums_path")/checksums.filtered.txt"

  python3 - <<'PY' "$checksums_path" "$filtered_path" "$binary_name" "$framework_name"
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text().splitlines()
target = {sys.argv[3], sys.argv[4]}
filtered = [line for line in source if any(line.endswith(name) for name in target)]
if len(filtered) != 2:
    raise SystemExit("Could not find expected assets in checksums.txt")
Path(sys.argv[2]).write_text("\n".join(filtered) + "\n")
PY

  if command -v shasum >/dev/null 2>&1; then
    (cd "$(dirname "$checksums_path")" && shasum -a 256 -c "$(basename "$filtered_path")" --status)
  elif command -v sha256sum >/dev/null 2>&1; then
    (cd "$(dirname "$checksums_path")" && sha256sum -c "$(basename "$filtered_path")" >/dev/null)
  else
    echo "Checksum verification requires shasum or sha256sum" >&2
    exit 1
  fi
}

print_path_hint() {
  cat <<EOF

Your PATH does not currently include:
  $bin_dir

Add it for future shells with:
EOF

  case "$shell_name" in
    zsh)
      cat <<EOF
  echo 'export PATH="$bin_dir:\$PATH"' >> ~/.zshrc
  source ~/.zshrc
EOF
      ;;
    bash)
      cat <<EOF
  echo 'export PATH="$bin_dir:\$PATH"' >> ~/.bashrc
  source ~/.bashrc
EOF
      ;;
    *)
      cat <<EOF
  export PATH="$bin_dir:\$PATH"
EOF
      ;;
  esac
}

final_message() {
  version="$1"
  current_link="$home_base/current"
  cat <<EOF
Thunder installed.

Version:
  $version

Binary:
  $bin_dir/thunder

Framework home:
  $current_link

Next steps:
  thunder --version
  thunder doctor
  thunder new my-app
  cd my-app
  npm install
  dune build
EOF

  if [ "$path_contains_bin_dir" -eq 0 ]; then
    print_path_hint
  fi
}

install_into_home() {
  version="$1"
  binary_path="$2"
  framework_source_dir="$3"
  version_dir="$home_base/versions/$version"
  current_link="$home_base/current"

  mkdir -p "$bin_dir" "$home_base/versions"
  rm -rf "$version_dir"
  mkdir -p "$version_dir"

  cp "$framework_source_dir/dune-project" "$version_dir/dune-project"
  cp -R "$framework_source_dir/packages" "$version_dir/packages"
  cp -R "$framework_source_dir/worker_runtime" "$version_dir/worker_runtime"
  cp -R "$framework_source_dir/scripts" "$version_dir/scripts"

  rm -f "$version_dir/worker_runtime/generated_wasm_assets.mjs"

  cp "$binary_path" "$version_dir/thunder"
  chmod +x "$version_dir/thunder"

  ln -sfn "$version_dir" "$current_link"
  ln -sfn "$current_link/thunder" "$bin_dir/thunder"

  final_message "$version"
}

install_from_local_repo() {
  version="${THUNDER_VERSION:-$(repo_version)}"
  version="$(trim_tag_prefix "$version")"
  binary_source="${THUNDER_BINARY_SOURCE:-$repo_root/_build/default/packages/thunder_cli/main.exe}"

  if [ ! -f "$binary_source" ]; then
    echo "Thunder binary not found at $binary_source" >&2
    echo "Build it first with: opam exec -- dune build packages/thunder_cli/main.exe" >&2
    exit 1
  fi

  install_into_home "$version" "$binary_source" "$repo_root"
}

install_from_release_assets() {
  require_command curl
  require_command python3
  require_command tar

  version="$(ensure_release_version)"
  tag="$(release_tag_for_version "$version")"
  os_name="$(platform_os)"
  arch_name="$(platform_arch)"
  binary_asset="thunder-$version-$os_name-$arch_name"
  framework_asset="thunder-framework-$version.tar.gz"
  checksums_asset="checksums.txt"
  release_download_base="https://github.com/$release_repo/releases/download/$tag"

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT INT TERM

  if [ -n "$asset_dir" ]; then
    download_file "$binary_asset" "$tmp_dir/$binary_asset"
    download_file "$framework_asset" "$tmp_dir/$framework_asset"
    download_file "$checksums_asset" "$tmp_dir/$checksums_asset"
  elif [ -n "$asset_base_url" ]; then
    download_file "$binary_asset" "$tmp_dir/$binary_asset"
    download_file "$framework_asset" "$tmp_dir/$framework_asset"
    download_file "$checksums_asset" "$tmp_dir/$checksums_asset"
  else
    download_file "$release_download_base/$binary_asset" "$tmp_dir/$binary_asset"
    download_file "$release_download_base/$framework_asset" "$tmp_dir/$framework_asset"
    download_file "$release_download_base/$checksums_asset" "$tmp_dir/$checksums_asset"
  fi

  verify_checksums "$tmp_dir/$checksums_asset" "$binary_asset" "$framework_asset"

  framework_dir="$tmp_dir/framework"
  mkdir -p "$framework_dir"
  tar -xzf "$tmp_dir/$framework_asset" -C "$framework_dir"

  install_into_home "$version" "$tmp_dir/$binary_asset" "$framework_dir"
}

if local_install_available; then
  install_from_local_repo
else
  install_from_release_assets
fi
