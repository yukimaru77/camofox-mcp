#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
api_key="$(sed -n 's/^CAMOFOX_API_KEY=//p' "$repo_dir/.env")"
base_url="${CAMOFOX_URL:-http://127.0.0.1:9377}"
user_id="${CAMOFOX_USER_ID:-default}"
tab_id="${1:-}"

if [[ -z "$tab_id" ]]; then
  tab_id="$(
    curl -fsS -H "Authorization: Bearer $api_key" "$base_url/tabs?userId=$user_id" |
      node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8")); const tab=(j.tabs||[]).find(t => /chatgpt\\.com/.test(t.url || "")) || (j.tabs||[])[0]; if (tab) process.stdout.write(tab.tabId);'
  )"
fi

if [[ -z "$tab_id" ]]; then
  echo '{"responding":false,"reason":"no_tab"}'
  exit 0
fi

curl -fsS -X POST \
  -H "Authorization: Bearer $api_key" \
  -H 'Content-Type: application/json' \
  --max-time 30 \
  -d "{\"userId\":\"$user_id\",\"expression\":\"(() => { const buttons = Array.from(document.querySelectorAll('button,[role=button]')); const stop = buttons.find(el => /Stop answering/i.test([el.getAttribute('aria-label'), el.textContent].join(' '))); return {responding: Boolean(stop), reason: stop ? 'stop_answering_button' : 'no_stop_answering_button'}; })()\"}" \
  "$base_url/tabs/$tab_id/evaluate" |
  node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8")); console.log(JSON.stringify(j.result ?? j));'
