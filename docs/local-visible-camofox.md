# Local Visible Camofox

This fork includes local helper scripts for running Camofox on the visible GNOME desktop while keeping the agent's browser profile stable.

## Input Shield

The input shield is an invisible X11 `InputOnly` overlay above the visible Camoufox window. It does not draw anything. It only absorbs your physical mouse hover/click events so they do not interfere with agent-driven browser actions.

Agent actions still work because Camofox sends them through the browser automation protocol.

## Commands

From the repository root:

```bash
scripts/camofox-input-shield.sh status
scripts/camofox-input-shield.sh on
scripts/camofox-input-shield.sh off
scripts/camofox-input-shield.sh toggle
```

Aliases:

- `on`: `start`, `enable`, `restore`
- `off`: `stop`, `disable`, `remove`, `delete`

## Keyboard Shortcuts

Install GNOME shortcuts:

```bash
scripts/camofox-input-shield.sh install-shortcuts
```

Default shortcuts:

- `Ctrl+Alt+I`: toggle the input shield
- `Ctrl+Alt+Shift+I`: disable/remove the input shield
- `Ctrl+Alt+Super+I`: enable/restore the input shield

Remove the shortcuts:

```bash
scripts/camofox-input-shield.sh uninstall-shortcuts
```

## Visible Native Launch

`scripts/camofox-browser-native.sh` starts `camofox-browser` natively. When a local X11 desktop is available, it uses visible mode:

```text
DISPLAY=unix/:1
CAMOFOX_HEADLESS=false
```

It also starts the input shield automatically. Set `CAMOFOX_VISIBLE_DESKTOP=false` to disable visible desktop integration.
