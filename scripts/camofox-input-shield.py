#!/usr/bin/env python3
"""Invisible desktop-side input shield for visible Camoufox windows.

This creates an X11 InputOnly window over the visible Camoufox window. It draws
nothing, but physical pointer events target the shield instead of the browser.
Camofox/Playwright protocol actions still target the page directly.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import time

from Xlib import X, display


DISPLAY = os.environ.get("DISPLAY") or "unix/:1"
XAUTHORITY = os.environ.get("XAUTHORITY") or f"/run/user/{os.getuid()}/gdm/Xauthority"
POLL_SECONDS = int(os.environ.get("CAMOFOX_INPUT_SHIELD_POLL_MS", "300")) / 1000


def wmctrl_windows() -> list[tuple[str, str]]:
    try:
        lines = run_x(["wmctrl", "-lp"]).splitlines()
    except Exception:
        return []

    windows: list[tuple[str, str]] = []
    for line in lines:
        parts = line.split(maxsplit=4)
        if not parts:
            continue
        title = parts[4] if len(parts) >= 5 else ""
        windows.append((parts[0], title))
    return windows


def run_x(args: list[str]) -> str:
    env = os.environ.copy()
    env["DISPLAY"] = DISPLAY
    env["XAUTHORITY"] = XAUTHORITY
    return subprocess.check_output(args, env=env, text=True, stderr=subprocess.DEVNULL)


def find_camoufox_window() -> str | None:
    matches: list[tuple[int, str]] = []
    for index, (window_id, title) in enumerate(wmctrl_windows()):
        if "Camoufox" not in title and "camoufox" not in title:
            continue
        score = index
        if "ChatGPT" in title:
            score += 40
        if "— Camoufox" in title or "- Camoufox" in title:
            score += 20
        if title.strip() == "Camoufox":
            score -= 100
        matches.append((score, window_id))
    if not matches:
        return None
    return max(matches)[1]


def close_blank_camoufox_windows() -> None:
    has_content_window = any(
        ("— Camoufox" in title or "- Camoufox" in title) and title.strip() != "Camoufox"
        for _, title in wmctrl_windows()
    )
    if not has_content_window:
        return

    for window_id, title in wmctrl_windows():
        if title.strip() == "Camoufox":
            try:
                run_x(["wmctrl", "-i", "-c", window_id])
            except Exception:
                try:
                    run_x(["xdotool", "windowminimize", window_id])
                except Exception:
                    pass


def window_geometry(window_id: str) -> tuple[int, int, int, int] | None:
    try:
        info = run_x(["xwininfo", "-id", window_id])
    except Exception:
        return None

    values: dict[str, int] = {}
    for key, pattern in {
        "x": r"Absolute upper-left X:\s+(-?\d+)",
        "y": r"Absolute upper-left Y:\s+(-?\d+)",
        "w": r"Width:\s+(\d+)",
        "h": r"Height:\s+(\d+)",
    }.items():
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

    dpy = display.Display(DISPLAY)
    screen = dpy.screen()
    root = screen.root

    event_mask = (
        X.ButtonPressMask
        | X.ButtonReleaseMask
        | X.PointerMotionMask
        | X.EnterWindowMask
        | X.LeaveWindowMask
        | X.KeyPressMask
        | X.KeyReleaseMask
    )
    shield = root.create_window(
        0,
        0,
        1,
        1,
        0,
        0,
        X.InputOnly,
        X.CopyFromParent,
        override_redirect=True,
        event_mask=event_mask,
    )
    shield.set_wm_name("camofox-input-shield")
    dpy.sync()

    mapped = False
    last_geometry: tuple[int, int, int, int] | None = None

    while True:
        close_blank_camoufox_windows()
        window_id = find_camoufox_window()
        geometry = window_geometry(window_id) if window_id else None
        if geometry is None:
            if mapped:
                shield.unmap()
                mapped = False
                dpy.sync()
            last_geometry = None
        else:
            x, y, width, height = geometry
            if geometry != last_geometry:
                shield.configure(x=x, y=y, width=width, height=height, stack_mode=X.Above)
                last_geometry = geometry
            else:
                shield.configure(stack_mode=X.Above)
            if not mapped:
                shield.map()
                mapped = True
            dpy.sync()

        while dpy.pending_events():
            dpy.next_event()
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(0)
    except Exception as exc:
        print(f"camofox-input-shield failed: {exc}", file=sys.stderr)
        raise
