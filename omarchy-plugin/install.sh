#!/bin/bash
# Install the Omarchy bar plugin vim.discord-ptt (Omarchy 4.x shell).
#   ./omarchy-plugin/install.sh            install / update and enable on the bar
#   ./omarchy-plugin/install.sh --remove   disable and remove the plugin
#
# The plugin folder is assembled from omarchy-plugin/vim.discord-ptt (QML, manifest,
# key capture) plus the shared daemon/discord_ptt.py and sounds/ from the repo root,
# so the daemon exists in one place for both the GNOME extension and Omarchy.
#
# Requirements: python-evdev, pactl/paplay (PipeWire), user in the `input` group.
# Settings live in ~/.config/omarchy/discord-ptt.json (key code, sound, on/off).
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
ID=vim.discord-ptt
DEST=$HOME/.config/omarchy/plugins/$ID

if [[ ${1:-} == --remove ]]; then
  omarchy plugin disable "$ID" >/dev/null 2>&1 || true
  rm -rf "$DEST"
  echo "removed $DEST"
  exit 0
fi

command -v omarchy >/dev/null || { echo "omarchy not found: this installer is for Omarchy" >&2; exit 1; }
python3 -c 'import evdev' 2>/dev/null || echo "warning: python-evdev missing (sudo pacman -S python-evdev)" >&2
id -nG | tr ' ' '\n' | grep -qx input || echo "warning: $USER is not in the input group (sudo usermod -aG input $USER, then re-login)" >&2

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -r "$REPO/omarchy-plugin/$ID/." "$tmp/"
install -m755 "$REPO/daemon/discord_ptt.py" "$tmp/daemon/discord_ptt.py"
mkdir -p "$tmp/sounds"
cp "$REPO/sounds/ptt_on.wav" "$REPO/sounds/ptt_off.wav" "$tmp/sounds/"

omarchy plugin validate "$tmp" >/dev/null
mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
cp -r "$tmp" "$DEST"
chmod 755 "$DEST"
echo "installed $DEST"

omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
if omarchy plugin list 2>/dev/null | grep -q "^$ID .*enabled"; then
  echo "already on the bar; to load new code: omarchy restart shell"
else
  omarchy plugin enable "$ID" --section right >/dev/null && echo "enabled on the bar (right)"
fi
