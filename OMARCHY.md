# GPPT on Omarchy / Hyprland

*Русский: [OMARCHY.ru.md](OMARCHY.ru.md)*

This is an alternative front-end for the same [`daemon/discord_ptt.py`](daemon/discord_ptt.py) used by the GNOME Shell extension (see [README.md](README.md)), for systems running **[Omarchy](https://omarchy.org/)** (Arch + Hyprland + a Quickshell-based bar) instead of GNOME Shell. The daemon itself is unmodified in behavior — it has no GNOME dependency to begin with — this just replaces how it's started/stopped and how you see its state:

| GNOME | Omarchy / Hyprland |
|---|---|
| `extension.js` panel button spawns/kills the daemon | `systemd --user` service (`omarchy/discord-ptt.service.template`) |
| `prefs.js` GTK settings window | `~/.config/discord-ptt/env` (PTT key) + a Quickshell bar widget (`omarchy/plugin/`) for status/on-off/restart |
| GSettings schema | plain env file, read by the systemd unit |

The GNOME extension files (`extension.js`, `prefs.js`, `metadata.json`, `schemas/`) aren't touched or needed here — GNOME Shell isn't running on Hyprland, so they just sit unused.

## Requirements

- Omarchy (or any Arch + Hyprland + this Quickshell bar setup).
- `python-evdev` (`omarchy pkg add python-evdev` — official `extra` repo, no AUR needed).
- `pipewire-pulse` (ships with Omarchy by default).
- Your user in the **`input`** group: `groups $(whoami)` should list `input`. If not: `sudo usermod -aG input $(whoami)`, then log out and back in.

## Install

```bash
git clone git@github.com:maksvini/gppt.git ~/vimaxstudio/gppt   # or wherever you keep it
cd ~/vimaxstudio/gppt
git checkout omarchy-hyprland     # or main, once merged
./omarchy/install.sh
```

The script is safe to re-run (e.g. after `git pull`, or after moving the repo — just re-run it and the unit file gets regenerated with the new path). It:

1. Installs `python-evdev` if missing.
2. Warns if you're not in the `input` group.
3. Generates the click sounds if `sounds/*.wav` are missing.
4. Writes `~/.config/systemd/user/discord-ptt.service`, with `ExecStart` pointing at **this exact repo checkout** (so the daemon always runs from wherever you cloned it — no separate "install" copy).
5. Writes `~/.config/discord-ptt/env` with `PTT_KEY=58` (Caps Lock) — **only if that file doesn't already exist**, so it won't clobber a key you've already set.
6. Installs the bar widget to `~/.config/omarchy/plugins/<your-username>.discord-ptt/` and enables it in the bar's right section.
7. `systemctl --user enable --now discord-ptt.service`.

## Changing the PTT key

Edit `~/.config/discord-ptt/env`:

```
PTT_KEY=58
PTT_EXTRA_ARGS=
```

`PTT_KEY` is a **raw evdev keycode** (not GDK/XKB — see the table in [CLAUDE.md](CLAUDE.md) or `omarchy/plugin/Model.js`'s `EVDEV_KEY_NAMES`), e.g. `58` = Caps Lock, `56` = Left Alt, `29` = Left Ctrl, `57` = Space. `PTT_EXTRA_ARGS` can hold extra daemon flags, e.g. `--no-sound` or `-v`.

After editing, apply it with either:

```bash
systemctl --user restart discord-ptt.service
```

or the **Restart service** button in the bar widget's popup (click the mic icon in the bar).

There's no in-widget key-capture UI (unlike the GNOME extension's GTK dialog) — Quickshell has no established pattern for grabbing exclusive keyboard input in a popup, and the daemon has no live-reload path anyway (any key change needs a restart), so editing the env file is the supported way for now.

## Verifying it works

```bash
systemctl --user status discord-ptt.service        # should be active (running)
journalctl --user -u discord-ptt.service -f         # daemon's own log
cat ~/.local/state/discord-ptt/state.json           # live state, updated on every press/release
```

`state.json` is what the bar widget watches (via Quickshell's `FileView`, event-driven — no polling) to show the mic icon and status. Expected shape:

```json
{"schema": 1, "service": "up", "holding": false, "muted": true, "keycode": 58, "sound_enabled": true, "ts": 1234567890.12}
```

In the bar: click the mic icon for status / an enable-disable switch / the restart button. The icon itself: dim = service not running, bright mic-off = running and muted (idle), bright mic-on = PTT key currently held.

## Uninstall

```bash
./omarchy/uninstall.sh
```

Stops/disables the service and removes the bar widget. Leaves `~/.config/discord-ptt/env` and `~/.local/state/discord-ptt/` in place (delete them yourself for a fully clean slate).

## Files added on this branch

```
omarchy/
  install.sh                        # idempotent installer
  uninstall.sh
  discord-ptt.service.template       # systemd --user unit (paths filled in by install.sh)
  env.example                        # default PTT_KEY=58
  plugin/
    manifest.json.template           # id/author filled in by install.sh
    Panel.qml                        # bar icon + popup (status, switch, restart)
    Service.qml                      # state-file watcher + systemctl control
    Model.js                         # evdev keycode names, state parsing, glyphs
daemon/discord_ptt.py                # +--state-file flag (additive, opt-in, no-op if unset)
OMARCHY.md / OMARCHY.ru.md           # this file
```
