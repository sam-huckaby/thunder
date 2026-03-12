#!/usr/bin/env bash
set -eu

root="packages"
if [ ! -d "$root" ]; then
  exit 0
fi

missing=0

for ml in $(find "$root" -name "*.ml" -type f); do
  case "$ml" in
    */main.ml) continue ;;
  esac
  mli="${ml%.ml}.mli"
  if [ ! -f "$mli" ]; then
    echo "Missing interface: $mli"
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  exit 1
fi

echo "All public modules have .mli files."
