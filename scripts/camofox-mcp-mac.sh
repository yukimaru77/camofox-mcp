#!/usr/bin/env bash
# macOS-adapted version of camofox-mcp-native.sh.
# Differences from upstream native script:
#   - Starts camofox-browser-mac.sh (no X11 logic) instead of camofox-browser-native.sh.
#   - Execs the LOCAL clone build (node dist/index.js) instead of `npx -y camofox-mcp@latest`.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

api_key=""
if [[ -f "$repo_dir/.env" ]]; then
  api_key="$(sed -n 's/^CAMOFOX_API_KEY=//p' "$repo_dir/.env")"
fi

log_dir="$HOME/.camofox-native/logs"
pid_file="$HOME/.camofox-native/browser.pid"
mkdir -p "$log_dir"

export CAMOFOX_URL="${CAMOFOX_URL:-http://127.0.0.1:9377}"
export CAMOFOX_API_KEY="${CAMOFOX_API_KEY:-$api_key}"
export CAMOFOX_TIMEOUT="${CAMOFOX_TIMEOUT:-120000}"

auth_args=()
if [[ -n "$CAMOFOX_API_KEY" ]]; then
  auth_args=(-H "Authorization: Bearer $CAMOFOX_API_KEY")
fi

# bash 3.2 (macOS default) treats empty-array expansion under `set -u` as
# unbound, so guard with the ${array[@]+...} idiom.
if ! curl -fsS ${auth_args[@]+"${auth_args[@]}"} "$CAMOFOX_URL/health" >/dev/null 2>&1; then
  nohup "$repo_dir/scripts/camofox-browser-mac.sh" >"$log_dir/browser.log" 2>&1 &
  echo "$!" >"$pid_file"

  for _ in $(seq 1 90); do
    if curl -fsS ${auth_args[@]+"${auth_args[@]}"} "$CAMOFOX_URL/health" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

exec node "$repo_dir/dist/index.js"
