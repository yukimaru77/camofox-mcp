#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
api_key="$(sed -n 's/^CAMOFOX_API_KEY=//p' "$repo_dir/.env")"

export CAMOFOX_HOST="${CAMOFOX_HOST:-127.0.0.1}"
export CAMOFOX_PORT="${CAMOFOX_PORT:-9377}"
export CAMOFOX_API_KEY="${CAMOFOX_API_KEY:-$api_key}"
export CAMOFOX_PROFILES_DIR="${CAMOFOX_PROFILES_DIR:-$HOME/.camofox-native/profiles}"
export CAMOFOX_VNC_TIMEOUT_MS="${CAMOFOX_VNC_TIMEOUT_MS:-86400000}"
export CAMOFOX_VNC_RESOLUTION="${CAMOFOX_VNC_RESOLUTION:-1280x720x24}"
export CAMOFOX_SCREEN_WIDTH="${CAMOFOX_SCREEN_WIDTH:-1280}"
export CAMOFOX_SCREEN_HEIGHT="${CAMOFOX_SCREEN_HEIGHT:-720}"
export HANDLER_TIMEOUT_MS="${HANDLER_TIMEOUT_MS:-120000}"
export CAMOFOX_TAB_LOCK_TIMEOUT_MS="${CAMOFOX_TAB_LOCK_TIMEOUT_MS:-120000}"

visible_desktop="${CAMOFOX_VISIBLE_DESKTOP:-true}"
uid="$(id -u)"

if [[ "$visible_desktop" != "false" && "$visible_desktop" != "0" ]]; then
  if [[ -z "${DISPLAY:-}" && -S /tmp/.X11-unix/X1 && -r "/run/user/$uid/gdm/Xauthority" ]]; then
    export DISPLAY=unix/:1
    export XAUTHORITY="/run/user/$uid/gdm/Xauthority"
  elif [[ "${DISPLAY:-}" =~ ^:([0-9]+)(\.[0-9]+)?$ && -S "/tmp/.X11-unix/X${BASH_REMATCH[1]}" && ! -e "/tmp/.X${BASH_REMATCH[1]}-lock" ]]; then
    export DISPLAY="unix/${DISPLAY}"
  fi

  if [[ -n "${DISPLAY:-}" ]]; then
    export CAMOFOX_HEADLESS="${CAMOFOX_HEADLESS:-false}"
  fi
fi

mkdir -p "$CAMOFOX_PROFILES_DIR" "$HOME/.camofox-native/logs"
exec node "$HOME/.camofox-native/pkg/node_modules/camofox-browser/dist/src/server.js"
