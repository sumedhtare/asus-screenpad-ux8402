#!/usr/bin/env bash
# Install the ASUS ScreenPad Plus tools (brightness, display on/off, touch/trackpad)
# for the current user. Safe to re-run. Needs sudo only for the udev rules.
#
#   ./install.sh            # full install
#   ./install.sh --no-keys  # skip setting GNOME keyboard shortcuts
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"
DO_KEYS=1
[ "${1:-}" = "--no-keys" ] && DO_KEYS=0

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

# ---- 1. dependencies -------------------------------------------------------
say "Checking dependencies"
miss=()
command -v brightnessctl >/dev/null || miss+=(brightnessctl)
command -v notify-send  >/dev/null || miss+=(libnotify-bin)
python3 -c 'import evdev' 2>/dev/null || miss+=(python3-evdev)
python3 -c 'import gi; gi.require_version("Gio","2.0")' 2>/dev/null || miss+=(python3-gi)
if [ "${#miss[@]}" -gt 0 ]; then
  echo "Missing packages: ${miss[*]}"
  echo "Install them with:  sudo apt install ${miss[*]}"
  read -rp "Try to install now with apt? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] && sudo apt install -y "${miss[@]}"
fi

# ---- 2. scripts ------------------------------------------------------------
say "Installing scripts to $BIN"
mkdir -p "$BIN"
install -m 0755 "$REPO"/bin/screenpad-brightness      "$BIN/"
install -m 0755 "$REPO"/bin/screenpad-toggle          "$BIN/"
install -m 0755 "$REPO"/bin/screenpad-trackpad        "$BIN/"
install -m 0755 "$REPO"/bin/screenpad-trackpad-daemon "$BIN/"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "NOTE: $BIN is not on PATH; add it to ~/.profile";; esac

# ---- 3. udev rules (sudo) --------------------------------------------------
say "Installing udev rules (needs sudo)"
sudo install -m 0644 "$REPO"/udev/90-screenpad-backlight.rules /etc/udev/rules.d/
sudo install -m 0644 "$REPO"/udev/91-screenpad-trackpad.rules  /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=backlight --subsystem-match=input
# bl_power/brightness need the 'video' group; touch+uinput need 'plugdev'.
for g in video plugdev; do
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx "$g"; then
    say "Adding $USER to '$g' group (log out/in for it to take effect)"
    sudo usermod -aG "$g" "$USER"
  fi
done

# ---- 4. systemd user service ----------------------------------------------
say "Installing + enabling the input daemon service"
mkdir -p "$UNIT_DIR"
install -m 0644 "$REPO"/systemd/screenpad-trackpad.service "$UNIT_DIR/"
systemctl --user daemon-reload
systemctl --user enable --now screenpad-trackpad.service || \
  echo "WARN: could not start service now (run 'systemctl --user start screenpad-trackpad.service' after login)"

# ---- 5. GNOME keyboard shortcuts ------------------------------------------
if [ "$DO_KEYS" = 1 ] && command -v gsettings >/dev/null; then
  say "Setting GNOME keyboard shortcuts"
  "$REPO/keybindings.sh"
else
  say "Skipping keyboard shortcuts"
fi

say "Done. Shortcuts: Super+F4/F5 brightness, Super+F8 display on/off, Super+F6 touch<->trackpad."
echo "If brightness or trackpad don't work yet, log out and back in (group membership)."
