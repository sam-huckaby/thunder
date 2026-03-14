#!/usr/bin/env bash
set -eu

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
binary_source="${THUNDER_BINARY_SOURCE:-$repo_root/_build/default/packages/thunder_cli/main.exe}"
version="${THUNDER_VERSION:-$(python3 - <<'PY' "$repo_root/package.json"
from pathlib import Path
import json
import sys
data = json.loads(Path(sys.argv[1]).read_text())
print(data.get('version', '0.1.0'))
PY
)}"
bin_dir="${THUNDER_BIN_DIR:-$HOME/.local/bin}"
home_base="${THUNDER_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/thunder}"
version_dir="$home_base/versions/$version"
current_link="$home_base/current"
shell_name="${SHELL##*/}"

path_contains_bin_dir=0
case ":${PATH:-}:" in
  *":$bin_dir:"*) path_contains_bin_dir=1 ;;
esac

mkdir -p "$bin_dir" "$home_base/versions"

if [ ! -f "$binary_source" ]; then
  echo "Thunder binary not found at $binary_source" >&2
  echo "Build it first with: opam exec -- dune build packages/thunder_cli/main.exe" >&2
  exit 1
fi

rm -rf "$version_dir"
mkdir -p "$version_dir"

cp "$repo_root/dune-project" "$version_dir/dune-project"
cp -R "$repo_root/packages" "$version_dir/packages"
cp -R "$repo_root/worker_runtime" "$version_dir/worker_runtime"
cp -R "$repo_root/scripts" "$version_dir/scripts"

rm -f "$version_dir/worker_runtime/generated_wasm_assets.mjs"

cp "$binary_source" "$version_dir/thunder"
chmod +x "$version_dir/thunder"

ln -sfn "$version_dir" "$current_link"
ln -sfn "$current_link/thunder" "$bin_dir/thunder"

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

cat <<EOF
Thunder installed.

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
