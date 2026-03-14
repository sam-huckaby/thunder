#!/usr/bin/env bash
set -eu

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fixture_root="${THUNDER_GENERATED_FIXTURE_DIR:-$(mktemp -d)}"
app_dir="$fixture_root/generated-app"

cleanup() {
  if [ "${THUNDER_KEEP_GENERATED_FIXTURE:-0}" = "1" ]; then
    printf 'Generated app fixture kept at %s\n' "$app_dir"
  else
    rm -rf "$fixture_root"
  fi
}

trap cleanup EXIT

cd "$repo_root"
opam exec -- dune build packages/thunder_cli/main.exe

opam exec -- dune exec ./packages/thunder_cli/main.exe -- new "$app_dir"

cd "$app_dir"
dune build @worker-build
env -u CLOUDFLARE_API_TOKEN dune build

printf 'Generated app fixture verified at %s\n' "$app_dir"
