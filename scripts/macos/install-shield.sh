#!/usr/bin/env bash
# Installs the Camofox input shield (Hammerspoon Lua module) into
# ~/.hammerspoon/ and wires it into init.lua. Idempotent.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
src="$repo_dir/scripts/macos/camofox-shield.lua"
hs_dir="$HOME/.hammerspoon"
dst="$hs_dir/camofox-shield.lua"
init="$hs_dir/init.lua"

mkdir -p "$hs_dir"
cp "$src" "$dst"
echo "installed: $dst"

# Append require + start to init.lua if not already present.
if ! { [[ -f "$init" ]] && grep -qE 'require\(\s*"camofox-shield"\s*\)' "$init"; }; then
  {
    if [[ -f "$init" ]]; then
      echo ""
    fi
    cat <<'EOF'
-- camofox-shield: blocks physical mouse on Camoufox page area while leaving
-- the URL/tab bar and any window stacked on top of Camoufox interactive.
hs.allowAppleScript(true)
local camofoxShield = require("camofox-shield")
camofoxShield.start()
EOF
  } >>"$init"
  echo "wired into: $init"
else
  echo "already wired into: $init (no change)"
fi

if pgrep -x Hammerspoon >/dev/null; then
  osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"' >/dev/null 2>&1 \
    || echo "note: Hammerspoon is running but AppleScript-driven reload failed. Reload manually (menubar icon → Reload Config)."
else
  echo "note: Hammerspoon is not running. Launch it from Applications and grant Accessibility permission."
fi
