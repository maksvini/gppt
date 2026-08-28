#!/usr/bin/env bash
# Reverses install.sh: stops/disables the systemd service and removes the bar
# widget. Leaves ~/.config/discord-ptt/env (your PTT key choice) untouched —
# delete it yourself if you want a totally clean slate.
set -euo pipefail

USER_NAME="$(id -un)"
PLUGIN_ID="${USER_NAME}.discord-ptt"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/${PLUGIN_ID}"

echo "==> Stopping and disabling discord-ptt.service..."
systemctl --user disable --now discord-ptt.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/discord-ptt.service"
systemctl --user daemon-reload

if command -v omarchy >/dev/null 2>&1; then
  echo "==> Removing bar widget '$PLUGIN_ID'..."
  omarchy plugin remove "$PLUGIN_ID" --yes 2>/dev/null || true
fi
rm -rf "$PLUGIN_DIR"

echo "Done. (Left ~/.config/discord-ptt/env and ~/.local/state/discord-ptt/ in place.)"
