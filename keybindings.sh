#!/usr/bin/env bash
# Bind the ScreenPad shortcuts as GNOME custom keybindings (idempotent):
#   Super+F4  brightness down     Super+F5  brightness up
#   Super+F8  display on/off      Super+F6  touch <-> trackpad
set -euo pipefail
BIN="$HOME/.local/bin"
SCHEMA=org.gnome.settings-daemon.plugins.media-keys
KB="$SCHEMA.custom-keybinding"
ROOT=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings

# id | binding | name | command
entries=(
  "screenpad-down|<Super>F4|ScreenPad brightness down|$BIN/screenpad-brightness down"
  "screenpad-up|<Super>F5|ScreenPad brightness up|$BIN/screenpad-brightness up"
  "screenpad-toggle|<Super>F8|ScreenPad display on/off|$BIN/screenpad-toggle"
  "screenpad-trackpad|<Super>F6|ScreenPad touch/trackpad|$BIN/screenpad-trackpad"
)

paths=()
for entry in "${entries[@]}"; do
  IFS='|' read -r id binding name cmd <<<"$entry"
  p="$ROOT/$id/"
  paths+=("'$p'")
  gsettings set "$KB:$p" name "$name"
  gsettings set "$KB:$p" command "$cmd"
  gsettings set "$KB:$p" binding "$binding"
done

# merge our paths into the existing list without dropping unrelated ones
existing=$(gsettings get "$SCHEMA" custom-keybindings)
list="$existing"
for p in "${paths[@]}"; do
  case "$list" in
    *"$p"*) : ;;                                   # already present
    *"@as []"*) list="[$p]" ;;                     # empty list
    *) list="${list%]}, $p]" ;;
  esac
done
gsettings set "$SCHEMA" custom-keybindings "$list"
echo "Keybindings set:"
gsettings get "$SCHEMA" custom-keybindings
