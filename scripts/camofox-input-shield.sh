#!/usr/bin/env bash
set -euo pipefail

uid="$(id -u)"
export DISPLAY="${DISPLAY:-unix/:1}"
export XAUTHORITY="${XAUTHORITY:-/run/user/$uid/gdm/Xauthority}"

exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/camofox-input-shield.py"
