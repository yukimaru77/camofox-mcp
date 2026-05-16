#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
log_dir="$HOME/.camofox-native/logs"
log_file="$log_dir/input-shield.log"
pid_pattern="$script_dir/camofox-input-shield.py"

uid="$(id -u)"
export DISPLAY="${DISPLAY:-unix/:1}"
export XAUTHORITY="${XAUTHORITY:-/run/user/$uid/gdm/Xauthority}"

mkdir -p "$log_dir"

is_running() {
  pgrep -f "$pid_pattern" >/dev/null 2>&1
}

status() {
  if is_running; then
    echo "camofox input shield: on"
    pgrep -af "$pid_pattern"
  else
    echo "camofox input shield: off"
  fi
}

start_shield() {
  if is_running; then
    status
    return 0
  fi
  setsid -f bash -c "exec '$0' run >>'$log_file' 2>&1"
  sleep 0.3
  status
}

stop_shield() {
  local pids
  pids="$(pgrep -f "$pid_pattern" || true)"
  if [[ -z "$pids" ]]; then
    echo "camofox input shield: already off"
    return 0
  fi
  while read -r pid; do
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  done <<<"$pids"
  sleep 0.3
  echo "camofox input shield: off"
}

install_shortcuts() {
  python3 - "$repo_dir/scripts/camofox-input-shield.sh" <<'PY'
import ast
import subprocess
import sys

script = sys.argv[1]
schema = "org.gnome.settings-daemon.plugins.media-keys"
base = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
entries = {
    base + "camofox-input-shield-toggle/": (
        "Toggle Camofox input shield",
        f"{script} toggle",
        "<Control><Alt>i",
    ),
    base + "camofox-input-shield-off/": (
        "Disable Camofox input shield",
        f"{script} off",
        "<Control><Alt><Shift>i",
    ),
    base + "camofox-input-shield-on/": (
        "Enable Camofox input shield",
        f"{script} on",
        "<Control><Alt><Super>i",
    ),
}

def run(*args):
    return subprocess.check_output(["gsettings", *args], text=True).strip()

raw = run("get", schema, "custom-keybindings")
current = [] if raw == "@as []" else ast.literal_eval(raw)
for path in entries:
    if path not in current:
        current.append(path)
run("set", schema, "custom-keybindings", repr(current))

for path, (name, command, binding) in entries.items():
    reloc = f"{schema}.custom-keybinding:{path}"
    run("set", reloc, "name", name)
    run("set", reloc, "command", command)
    run("set", reloc, "binding", binding)
PY
  cat <<'EOF'
Installed Camofox input shield shortcuts:
  Ctrl+Alt+I         toggle shield
  Ctrl+Alt+Shift+I   disable/remove shield
  Ctrl+Alt+Super+I   enable/restore shield
EOF
}

uninstall_shortcuts() {
  python3 - <<'PY'
import ast
import subprocess

schema = "org.gnome.settings-daemon.plugins.media-keys"
base = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
remove = {
    base + "camofox-input-shield-toggle/",
    base + "camofox-input-shield-off/",
    base + "camofox-input-shield-on/",
}

def run(*args):
    return subprocess.check_output(["gsettings", *args], text=True).strip()

raw = run("get", schema, "custom-keybindings")
current = [] if raw == "@as []" else ast.literal_eval(raw)
current = [path for path in current if path not in remove]
run("set", schema, "custom-keybindings", repr(current))
PY
  echo "Removed Camofox input shield shortcuts"
}

case "${1:-run}" in
  run)
    exec python3 "$script_dir/camofox-input-shield.py"
    ;;
  on|start|enable|restore)
    start_shield
    ;;
  off|stop|disable|remove|delete)
    stop_shield
    ;;
  toggle)
    if is_running; then
      stop_shield
    else
      start_shield
    fi
    ;;
  status)
    status
    ;;
  install-shortcuts)
    install_shortcuts
    ;;
  uninstall-shortcuts)
    uninstall_shortcuts
    ;;
  *)
    cat <<'EOF'
Usage: camofox-input-shield.sh [run|on|off|toggle|status|install-shortcuts|uninstall-shortcuts]

Aliases:
  on:      start, enable, restore
  off:     stop, disable, remove, delete

Shortcuts after install-shortcuts:
  Ctrl+Alt+I         toggle shield
  Ctrl+Alt+Shift+I   disable/remove shield
  Ctrl+Alt+Super+I   enable/restore shield
EOF
    exit 2
    ;;
esac
