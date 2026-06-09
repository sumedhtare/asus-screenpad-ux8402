#!/usr/bin/env bash
# Remove everything install.sh added. Leaves group membership and installed
# apt packages alone.
set -uo pipefail
BIN="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"
SCHEMA=org.gnome.settings-daemon.plugins.media-keys
ROOT=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

say "Stopping + disabling service"
systemctl --user disable --now screenpad-trackpad.service 2>/dev/null || true
rm -f "$UNIT_DIR/screenpad-trackpad.service"
systemctl --user daemon-reload 2>/dev/null || true

say "Removing scripts"
rm -f "$BIN"/screenpad-brightness "$BIN"/screenpad-toggle \
      "$BIN"/screenpad-trackpad "$BIN"/screenpad-trackpad-daemon

say "Removing udev rules (sudo)"
sudo rm -f /etc/udev/rules.d/90-screenpad-backlight.rules \
           /etc/udev/rules.d/91-screenpad-trackpad.rules
sudo udevadm control --reload || true

say "Removing GNOME keybindings"
for id in screenpad-down screenpad-up screenpad-toggle screenpad-trackpad; do
  p="$ROOT/$id/"
  list=$(gsettings get "$SCHEMA" custom-keybindings 2>/dev/null) || continue
  list=$(printf '%s' "$list" | sed -E "s/'$(printf '%s' "$p" | sed 's:/:\\/:g')'//; s/, ,/,/g; s/\[, /[/; s/, \]/]/")
  gsettings set "$SCHEMA" custom-keybindings "$list" 2>/dev/null || true
done

say "Done. (Caches in ~/.cache/screenpad-* and group membership were left in place.)"
rm -f ~/.cache/screenpad-trackpad.pid ~/.cache/screenpad-trackpad.mode 2>/dev/null || true
