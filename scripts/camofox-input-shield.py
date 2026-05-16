#!/usr/bin/env python3
"""Transparent desktop-side input shield for visible Camoufox windows.

The shield follows the top-level Camoufox window and consumes physical mouse
events before they reach the browser. Camofox/Playwright protocol actions still
target the page directly.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import time
import tkinter as tk


DISPLAY = os.environ.get("DISPLAY") or "unix/:1"
XAUTHORITY = os.environ.get("XAUTHORITY") or f"/run/user/{os.getuid()}/gdm/Xauthority"
POLL_MS = int(os.environ.get("CAMOFOX_INPUT_SHIELD_POLL_MS", "500"))
ALPHA = float(os.environ.get("CAMOFOX_INPUT_SHIELD_ALPHA", "0.01"))


def run_x(args: list[str]) -> str:
    env = os.environ.copy()
    env["DISPLAY"] = DISPLAY
    env["XAUTHORITY"] = XAUTHORITY
    return subprocess.check_output(args, env=env, text=True, stderr=subprocess.DEVNULL)


def find_camoufox_window() -> str | None:
    try:
        lines = run_x(["wmctrl", "-lp"]).splitlines()
    except Exception:
        return None

    matches: list[tuple[int, str]] = []
    for index, line in enumerate(lines):
        if "Camoufox" not in line and "camoufox" not in line:
            continue
        parts = line.split(maxsplit=4)
        if not parts:
            continue
        title = parts[4] if len(parts) >= 5 else ""
        score = 0
        if "— Camoufox" in title or "- Camoufox" in title:
            score += 20
        if title.strip() == "Camoufox":
            score += 10
        matches.append((score + index, parts[0]))
    if not matches:
        return None
    return max(matches)[1]


def window_geometry(window_id: str) -> tuple[int, int, int, int] | None:
    try:
        info = run_x(["xwininfo", "-id", window_id])
    except Exception:
        return None

    patterns = {
        "x": r"Absolute upper-left X:\s+(-?\d+)",
        "y": r"Absolute upper-left Y:\s+(-?\d+)",
        "w": r"Width:\s+(\d+)",
        "h": r"Height:\s+(\d+)",
    }
    values: dict[str, int] = {}
    for key, pattern in patterns.items():
        match = re.search(pattern, info)
        if not match:
            return None
        values[key] = int(match.group(1))
    if values["w"] < 50 or values["h"] < 50:
        return None
    return values["x"], values["y"], values["w"], values["h"]


def main() -> int:
    os.environ["DISPLAY"] = DISPLAY
    os.environ["XAUTHORITY"] = XAUTHORITY

    root = tk.Tk()
    root.withdraw()
    root.overrideredirect(True)
    root.attributes("-topmost", True)
    root.attributes("-alpha", ALPHA)
    root.configure(background="black", cursor="arrow")

    for event in (
        "<Motion>",
        "<Enter>",
        "<Leave>",
        "<Button>",
        "<ButtonRelease>",
        "<MouseWheel>",
        "<Key>",
        "<KeyRelease>",
    ):
        root.bind(event, lambda _event: "break")

    last_geometry: tuple[int, int, int, int] | None = None

    def tick() -> None:
        nonlocal last_geometry
        window_id = find_camoufox_window()
        geometry = window_geometry(window_id) if window_id else None
        if geometry is None:
            root.withdraw()
            last_geometry = None
        else:
            x, y, width, height = geometry
            if geometry != last_geometry:
                root.geometry(f"{width}x{height}+{x}+{y}")
                last_geometry = geometry
            root.deiconify()
            root.lift()
        root.after(POLL_MS, tick)

    tick()
    root.mainloop()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(0)
    except Exception as exc:
        print(f"camofox-input-shield failed: {exc}", file=sys.stderr)
        time.sleep(1)
        raise
