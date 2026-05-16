#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
api_key="$(sed -n 's/^CAMOFOX_API_KEY=//p' "$repo_dir/.env")"
log_dir="$HOME/.camofox-native/logs"
pid_file="$HOME/.camofox-native/browser.pid"

mkdir -p "$log_dir"

export CAMOFOX_URL="${CAMOFOX_URL:-http://127.0.0.1:9377}"
export CAMOFOX_API_KEY="${CAMOFOX_API_KEY:-$api_key}"
export CAMOFOX_TIMEOUT="${CAMOFOX_TIMEOUT:-120000}"

if ! curl -fsS -H "Authorization: Bearer $CAMOFOX_API_KEY" "$CAMOFOX_URL/health" >/dev/null 2>&1; then
  nohup "$repo_dir/scripts/camofox-browser-native.sh" >"$log_dir/browser.log" 2>&1 &
  echo "$!" >"$pid_file"

  for _ in $(seq 1 90); do
    if curl -fsS -H "Authorization: Bearer $CAMOFOX_API_KEY" "$CAMOFOX_URL/health" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

exec npx -y camofox-mcp@latest
