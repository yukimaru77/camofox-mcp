# Running Camofox on macOS (visible + input-shielded)

This fork's "Local Visible Camofox" helpers (`scripts/camofox-browser-native.sh`,
`scripts/camofox-input-shield.sh`) target GNOME/X11 and don't run on macOS:

- They set `DISPLAY` / `XAUTHORITY` and start an Xvfb-style virtual display.
- The input shield is an X11 overlay window that uses `XInput` to grab events.
- VNC env vars (`CAMOFOX_VNC_*`) assume Xvfb/x11vnc.

This document covers the macOS-equivalent path: visible Camoufox windows
on the macOS desktop with an `hs.eventtap`-based input shield. Playwright /
CDP-driven automation (i.e. anything called via the MCP server) goes through
the browser's internal input pipeline, not macOS `NSEvent`, so the shield
does not interfere with it.

## Prerequisites

- macOS (tested on 14.x; Camoufox ships universal `arm64` + `x86_64` builds).
- Node.js ≥ 18.
- Homebrew (for installing Hammerspoon).

## Setup

### 1. Install Camofox MCP locally (the clone)

```bash
git clone https://github.com/yukimaru77/camofox-mcp.git ~/camofox-mcp
cd ~/camofox-mcp
git checkout macos-support
npm install
npm run build
```

### 2. Install the Camofox browser server

The Mac launcher (next step) execs `~/.camofox-native/pkg/node_modules/camofox-browser/dist/src/server.js`,
mirroring the directory layout the fork's Linux launcher uses. Install it once:

```bash
mkdir -p ~/.camofox-native/pkg
cd ~/.camofox-native/pkg
npm init -y >/dev/null
npm install camofox-browser@latest
```

Camoufox itself (the Firefox-based browser) is downloaded on first launch
into `~/Library/Caches/camoufox/Camoufox.app`.

### 3. Wire the MCP server into Claude Code (user scope)

```bash
claude mcp add camofox -s user -- \
  ~/camofox-mcp/scripts/camofox-mcp-mac.sh
```

That points Claude Code at `scripts/camofox-mcp-mac.sh`, which (a) health-
checks `127.0.0.1:9377`, (b) starts `scripts/camofox-browser-mac.sh` in the
background if nothing is listening, then (c) execs the locally-built MCP
server (`node dist/index.js`). No `CAMOFOX_URL` env var is needed because
the launcher sets it.

### 4. Install the input shield (Hammerspoon)

```bash
brew install --cask hammerspoon
~/camofox-mcp/scripts/macos/install-shield.sh
open -a Hammerspoon
```

The first time Hammerspoon launches it asks for **Accessibility** permission.
Grant it in System Settings → Privacy & Security → Accessibility. The shield
needs Accessibility to (a) read window frames via the AX API and (b) install
an event tap that drops physical mouse events.

## What changed vs. the upstream native (Linux) helpers

| Upstream native helper                       | macOS replacement                              |
|----------------------------------------------|------------------------------------------------|
| `scripts/camofox-browser-native.sh`          | `scripts/camofox-browser-mac.sh`               |
| `scripts/camofox-mcp-native.sh`              | `scripts/camofox-mcp-mac.sh`                   |
| `scripts/camofox-input-shield.sh` (X11)      | `scripts/macos/camofox-shield.lua` (Hammerspoon) |
| X11 `DISPLAY` / `XAUTHORITY` bootstrap       | Removed — macOS uses Aqua, no X11             |
| `CAMOFOX_VNC_*` env vars                     | Removed — no Xvfb/x11vnc on macOS              |
| Fixed `CAMOFOX_SCREEN_WIDTH/HEIGHT`          | Removed — see "Fingerprint OS" below           |
| (Implicit) `hostOS = linux`                  | `CAMOFOX_OS=windows` default                   |

### Fingerprint OS (`CAMOFOX_OS=windows`)

`browserforge`'s fingerprint dataset (as shipped with the `camofox-browser`
version this fork pins) has no satisfiable profile under `hostOS=macos` once
the persistent-context launch path adds its other constraints. With
`hostOS=macos` you get:

```
persistent context launch failed: No headers based on this input can be
generated. Please relax or change some of the requirements you specified.
```

`scripts/camofox-browser-mac.sh` defaults `CAMOFOX_OS=windows` to dodge this.
The macOS Camoufox binary still runs locally — only the outbound fingerprint
reports Windows, which is also a sensible default for anti-detection work
since most real users browse from Windows. Override with `CAMOFOX_OS=linux`
(or `macos` if a future version's dataset adds support).

### Fixed screen size disabled

The fork's Linux launcher pins `CAMOFOX_SCREEN_WIDTH=1280`/`HEIGHT=720` to
match Xvfb's resolution. On macOS we don't run Xvfb, and constraining the
fingerprint to that exact size combines badly with `CAMOFOX_OS=windows` to
re-trigger the "No headers can be generated" error. We unset both so
browserforge picks a satisfiable screen automatically.

### Bash 3.2 quirk

`scripts/camofox-mcp-mac.sh` uses `${array[@]+"${array[@]}"}` instead of
plain `"${array[@]}"` because macOS ships bash 3.2, which treats empty-
array expansion under `set -u` as an unbound-variable error.

## How the shield works

`scripts/macos/camofox-shield.lua` registers a single `hs.eventtap` that
filters mouseMoved / leftMouseDown / leftMouseUp / leftMouseDragged /
rightMouse{Down,Up,Dragged} / otherMouse{Down,Up,Dragged} / scrollWheel.

For each event, the callback decides whether to consume it:

1. Take the event's mouse location.
2. Walk a cached front-to-back list of windows (refreshed at ~30 Hz via
   `hs.window.orderedWindows()`) and find the topmost window whose frame
   contains the point.
3. If that topmost window belongs to Camoufox **and** the point is below
   the chrome (i.e. `y >= window.y + CHROME_HEIGHT`, default 90 px), eat
   the event. Otherwise let it through.
4. On `mouseDown` events, the cache is refreshed synchronously first so a
   freshly-raised window above Camoufox is reflected before deciding.

That gives:

- Physical hover/click/scroll on visible Camoufox page area → blocked.
- Title bar / tab strip / URL bar (top `CHROME_HEIGHT` px) → interactive, so
  the user can drag the window, switch tabs, type URLs.
- Any other window stacked visually on top of Camoufox → unaffected; clicks
  in the overlap region reach that window normally.
- Playwright/CDP automation → unaffected (doesn't go through `NSEvent`).

### Hotkeys

| Shortcut             | Action            |
|----------------------|-------------------|
| `Ctrl+Alt+I`         | Toggle shield     |
| `Ctrl+Alt+Cmd+I`     | Enable shield     |
| `Ctrl+Alt+Shift+I`   | Disable shield    |

These match the fork's X11 input-shield bindings.

### Tuning `CHROME_HEIGHT`

If you enable the Firefox bookmarks bar or otherwise change the chrome
height, edit the constant near the top of `~/.hammerspoon/camofox-shield.lua`
and reload Hammerspoon (menubar icon → Reload Config, or `Ctrl+Alt+Cmd+R` if
you copied the helper hotkey from this fork's example init.lua).

## Verifying the setup

```bash
# Browser server reachable?
curl -fsS http://127.0.0.1:9377/health && echo

# MCP server registered and connecting?
claude mcp get camofox

# Shield active?
osascript -e 'tell application "Hammerspoon" to execute lua code "return require(\"camofox-shield\").debugDump()"'
```

`debugDump()` prints the eventtap state plus the first eight windows in the
front-to-back cache; the Camoufox entry is tagged `[SHIELD]`.

## Known limitations

- The shield depends on `hs.window.orderedWindows()`, which relies on the
  Accessibility API. Apps without AX windows (rare) won't appear in the
  ordering and could in principle be wrongly shielded; in practice the
  Camoufox entry will simply not match, so events flow through.
- Camoufox's persistent profile lives at `~/.camofox-native/profiles/default/`
  and is shared between sessions. Delete it to reset cookies / fingerprint
  if anti-detection state gets stuck.
- `CAMOFOX_API_KEY` is left unset by default (loopback-only deployment).
  Set it before binding `CAMOFOX_HOST` to anything beyond `127.0.0.1`.
