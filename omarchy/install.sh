#!/usr/bin/env bash
# Installs the discord-ptt daemon as a systemd --user service and adds the
# Discord PTT bar widget to Omarchy's Quickshell bar. Safe to re-run.
#
# Usage: ./omarchy/install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OMARCHY_DIR="$REPO_DIR/omarchy"
USER_NAME="$(id -un)"
PLUGIN_ID="${USER_NAME}.discord-ptt"

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
ENV_DIR="$HOME/.config/discord-ptt"
STATE_DIR="$HOME/.local/state/discord-ptt"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/${PLUGIN_ID}"

echo "==> Repo:      $REPO_DIR"
echo "==> Plugin id: $PLUGIN_ID"
echo

# ---- dependency: python-evdev -----------------------------------------------
if ! pacman -Qi python-evdev >/dev/null 2>&1; then
  echo "==> Installing python-evdev..."
  if command -v omarchy >/dev/null 2>&1; then
    omarchy pkg add python-evdev
  else
    sudo pacman -S --needed python-evdev
  fi
else
  echo "==> python-evdev already installed"
fi

# ---- input group check -------------------------------------------------------
if ! id -nG "$USER_NAME" | grep -qw input; then
  echo
  echo "WARNING: user '$USER_NAME' is not in the 'input' group."
  echo "  The daemon cannot read /dev/input/* without it. Fix with:"
  echo "    sudo usermod -aG input $USER_NAME"
  echo "  then log out and back in, and re-run this script."
  echo
fi

# ---- click sounds -------------------------------------------------------------
if [[ ! -f "$REPO_DIR/sounds/ptt_on.wav" || ! -f "$REPO_DIR/sounds/ptt_off.wav" ]]; then
  echo "==> Generating click sounds..."
  python3 "$REPO_DIR/daemon/generate_sounds.py"
fi

mkdir -p "$SYSTEMD_USER_DIR" "$ENV_DIR" "$STATE_DIR" "$PLUGIN_DIR"

# ---- systemd unit -------------------------------------------------------------
echo "==> Writing systemd unit ($SYSTEMD_USER_DIR/discord-ptt.service)..."
sed \
  -e "s|__PYTHON__|$(command -v python3)|g" \
  -e "s|__DAEMON__|$REPO_DIR/daemon/discord_ptt.py|g" \
  -e "s|__SOUND_ON__|$REPO_DIR/sounds/ptt_on.wav|g" \
  -e "s|__SOUND_OFF__|$REPO_DIR/sounds/ptt_off.wav|g" \
  "$OMARCHY_DIR/discord-ptt.service.template" > "$SYSTEMD_USER_DIR/discord-ptt.service"

# ---- env file (PTT key config) — don't clobber an existing choice -----------
if [[ ! -f "$ENV_DIR/env" ]]; then
  cp "$OMARCHY_DIR/env.example" "$ENV_DIR/env"
  echo "==> Wrote default $ENV_DIR/env (PTT_KEY=58, Caps Lock)"
else
  echo "==> $ENV_DIR/env already exists — leaving your PTT_KEY alone"
fi

# ---- bar widget plugin --------------------------------------------------------
echo "==> Installing bar widget as '$PLUGIN_ID'..."
cp "$OMARCHY_DIR/plugin/Panel.qml" "$OMARCHY_DIR/plugin/Service.qml" "$OMARCHY_DIR/plugin/Model.js" "$PLUGIN_DIR/"
sed \
  -e "s|__PLUGIN_ID__|$PLUGIN_ID|g" \
  -e "s|__AUTHOR__|$USER_NAME|g" \
  "$OMARCHY_DIR/plugin/manifest.json.template" > "$PLUGIN_DIR/manifest.json"

# ---- enable everything ---------------------------------------------------------
echo "==> Enabling systemd service..."
systemctl --user daemon-reload
systemctl --user enable --now discord-ptt.service

if command -v omarchy >/dev/null 2>&1; then
  echo "==> Validating and enabling bar widget..."
  omarchy plugin validate "$PLUGIN_DIR"
  omarchy plugin enable "$PLUGIN_ID" --section right
else
  echo "NOTE: 'omarchy' CLI not found — enable the widget manually:"
  echo "  omarchy plugin enable $PLUGIN_ID --section right"
fi

echo
echo "Done."
echo "  Check the daemon:  systemctl --user status discord-ptt.service"
echo "  Change the key:    edit $ENV_DIR/env, then: systemctl --user restart discord-ptt.service"
echo "  Live state:        cat $STATE_DIR/state.json"
