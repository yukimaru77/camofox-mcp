#!/usr/bin/env bash
# macOS-adapted version of camofox-browser-native.sh.
# Differences from the upstream native script:
#   - No X11/DISPLAY logic (macOS uses Quartz/Aqua, not X11).
#   - No input-shield (X11-only feature; Camoufox window appears as a normal Aqua window).
#   - Otherwise mirrors the fork's "visible desktop" defaults: persistent
#     profiles, long session/idle/VNC timeouts, visible (non-headless) mode.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

api_key=""
if [[ -f "$repo_dir/.env" ]]; then
  api_key="$(sed -n 's/^CAMOFOX_API_KEY=//p' "$repo_dir/.env")"
fi

export CAMOFOX_HOST="${CAMOFOX_HOST:-127.0.0.1}"
export CAMOFOX_PORT="${CAMOFOX_PORT:-9377}"
export CAMOFOX_API_KEY="${CAMOFOX_API_KEY:-$api_key}"
export CAMOFOX_PROFILES_DIR="${CAMOFOX_PROFILES_DIR:-$HOME/.camofox-native/profiles}"
# VNC / fixed screen size are Linux/Xvfb features and not used on macOS — leave
# CAMOFOX_SCREEN_WIDTH/HEIGHT unset so browserforge can pick a satisfiable
# screen for the chosen fingerprint OS (forcing 1280x720 caused
# "No headers can be generated" with CAMOFOX_OS=windows).
export HANDLER_TIMEOUT_MS="${HANDLER_TIMEOUT_MS:-120000}"

# Default evaluate-extended rate limit is 20 req/min/user, which is too
# tight for polling-heavy MCP clients (e.g. chatgpt-pro-mcp polling
# location.href every 500ms while waiting for a ChatGPT conversation to
# spin up). Raise it for loopback / single-user setups.
export CAMOFOX_EVAL_EXTENDED_RATE_LIMIT_MAX="${CAMOFOX_EVAL_EXTENDED_RATE_LIMIT_MAX:-1000}"
export CAMOFOX_EVAL_EXTENDED_RATE_LIMIT_WINDOW_MS="${CAMOFOX_EVAL_EXTENDED_RATE_LIMIT_WINDOW_MS:-60000}"
export CAMOFOX_TAB_LOCK_TIMEOUT_MS="${CAMOFOX_TAB_LOCK_TIMEOUT_MS:-120000}"
export CAMOFOX_SESSION_TIMEOUT="${CAMOFOX_SESSION_TIMEOUT:-86400000}"
export CAMOFOX_IDLE_TIMEOUT_MS="${CAMOFOX_IDLE_TIMEOUT_MS:-86400000}"
export CAMOFOX_IDLE_EXIT_TIMEOUT_MS="${CAMOFOX_IDLE_EXIT_TIMEOUT_MS:-86400000}"

# Visible-desktop default: render Camoufox windows on the macOS desktop
# instead of running headless. Override with CAMOFOX_HEADLESS=true if needed.
export CAMOFOX_HEADLESS="${CAMOFOX_HEADLESS:-false}"

# browserforge's fingerprint dataset has no satisfiable macOS profiles for
# the Camoufox version this fork ships, so persistent-context launches fail
# with "No headers based on this input can be generated" when hostOS=macos.
# Spoof as windows by default — the macOS Camoufox binary still runs locally,
# but the outbound fingerprint reports Windows (which is the typical
# anti-detection target anyway). Override with CAMOFOX_OS=linux|macos|windows.
export CAMOFOX_OS="${CAMOFOX_OS:-windows}"

mkdir -p "$CAMOFOX_PROFILES_DIR" "$HOME/.camofox-native/logs"

exec node "$HOME/.camofox-native/pkg/node_modules/camofox-browser/dist/src/server.js"
