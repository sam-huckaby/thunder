#!/usr/bin/env bash
set -eu

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "CLOUDFLARE_API_TOKEN is required for preview smoke validation." >&2
  exit 1
fi

backend="${1:-auto}"
account_id="${CLOUDFLARE_ACCOUNT_ID:-}"
worker_name_override="${THUNDER_SMOKE_WORKER_NAME:-}"

if [ "$backend" != "auto" ]; then
  echo "Unsupported backend: $backend" >&2
  echo "Thunder now supports a single production runtime path; use 'auto'." >&2
  exit 1
fi

echo "Running preview smoke with runtime path=$backend"
opam exec -- dune build @worker-build

deploy_config=""
for candidate in "_build/default/deploy/wrangler.toml" "_build/default/wrangler.toml"; do
  if [ -f "$candidate" ]; then
    deploy_config="$candidate"
    break
  fi
done

if [ -z "$deploy_config" ]; then
  echo "Deploy config not found after build." >&2
  exit 1
fi

mkdir -p .thunder
smoke_config="$(dirname "$deploy_config")/preview-smoke-${backend}.toml"
smoke_log=".thunder/preview-smoke-${backend}.log"
smoke_summary=".thunder/preview-smoke-${backend}.summary"

if [ -z "$account_id" ]; then
  whoami_output="$(npx wrangler whoami)"
  account_id="$(python3 - <<'PY' "$whoami_output"
import re
import sys

text = sys.argv[1]
match = re.search(r'\b([a-f0-9]{32})\b', text)
if match:
    print(match.group(1))
PY
)"
fi

python3 - <<'PY' "$deploy_config" "$smoke_config" "$backend" "$account_id" "$worker_name_override"
from pathlib import Path
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
backend = sys.argv[3]
account_id = sys.argv[4]
worker_name_override = sys.argv[5]
content = src.read_text()

if account_id:
    content = content.replace('account_id = "<your-cloudflare-account-id>"', f'account_id = "{account_id}"')
if worker_name_override:
    import re
    content = re.sub(r'^name = ".*"$', f'name = "{worker_name_override}"', content, flags=re.MULTILINE)
if 'compatibility_flags' not in content:
    content = content.replace('compatibility_date = "2026-03-12"', 'compatibility_date = "2026-03-12"\ncompatibility_flags = ["nodejs_compat"]')

dst.write_text(content)
PY

npx wrangler versions upload --config "$smoke_config" >"$smoke_log" 2>&1

if grep -q "This Worker does not exist on your account" "$smoke_log"; then
  echo "Preview smoke requires an existing Worker script for wrangler versions upload." >&2
  echo "Set THUNDER_SMOKE_WORKER_NAME to an existing Worker name, or create the Worker before retrying." >&2
  cat "$smoke_log" >&2
  exit 1
fi

preview_url="$(python3 - <<'PY' "$smoke_log"
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
text = re.sub(r'\x1b\[[0-9;]*m', '', text)
match = re.search(r'Version Preview URL:\s*(https://[^\s)]+)', text)
if not match:
    match = re.search(r'https://[^\s)]+workers\.dev', text)
if match:
    print(match.group(1) if match.lastindex else match.group(0))
PY
)"

version_id="$(python3 - <<'PY' "$smoke_log"
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
text = re.sub(r'\x1b\[[0-9;]*m', '', text)
match = re.search(r'([Vv]ersion ID:\s*|Worker Version ID:\s*|version_id=)([A-Za-z0-9-]+)', text)
if match:
    print(match.group(2))
PY
)"

if [ -z "$preview_url" ]; then
  echo "Failed to parse preview URL from $smoke_log" >&2
  cat "$smoke_log" >&2
  exit 1
fi

root_body="$(curl -fsSL "$preview_url/")"
health_body="$(curl -fsSL "$preview_url/health")"
echo_body="$(curl -fsSL -X POST "$preview_url/echo" -H "content-type: application/json" --data '{"storm":true}')"
missing_status="$(curl -s -o /dev/null -w '%{http_code}' "$preview_url/missing")"

case "$root_body" in
  *"Welcome to the storm"*) ;;
  *)
    echo "Root route did not return expected content" >&2
    exit 1
    ;;
esac

if [ "$health_body" != '{"ok":true}' ]; then
  echo "Health route returned unexpected body: $health_body" >&2
  exit 1
fi

if [ "$echo_body" != '{"storm":true}' ]; then
  echo "Echo route returned unexpected body: $echo_body" >&2
  exit 1
fi

if [ "$missing_status" != '404' ]; then
  echo "Missing route returned unexpected status: $missing_status" >&2
  exit 1
fi

if [ -f .thunder/preview.json ]; then
  echo "Preview metadata:"
  python3 - <<'PY'
from pathlib import Path

path = Path('.thunder/preview.json')
for line in path.read_text().splitlines():
    print(line)
PY
fi

cat >"$smoke_summary" <<EOF
backend=$backend
version_id=$version_id
preview_url=$preview_url
root=pass
health=pass
echo=pass
missing_404=pass
EOF

echo "Smoke summary written to $smoke_summary"
echo "Next steps: record preview results in docs/runtime_parity_matrix.md"
