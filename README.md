# asus-screenpad-ux8402

Linux tooling for the **ASUS Zenbook Pro 14 Duo OLED (UX8402ZE)** ScreenPad Plus,
bundled so it survives a reformat. Keyboard shortcuts for brightness, turning the
ScreenPad on/off, and switching the ScreenPad between a normal touchscreen and a
relative trackpad.

Tested on Ubuntu / GNOME 50 on Wayland.

## Shortcuts

| Shortcut   | Action                                        |
|------------|-----------------------------------------------|
| `Super+F4` | ScreenPad brightness **down**                 |
| `Super+F5` | ScreenPad brightness **up**                   |
| `Super+F8` | ScreenPad display **on/off** (persisted)      |
| `Super+F6` | ScreenPad **touch ⇄ trackpad** mode           |

Trackpad gestures: 1-finger move, 1-finger tap = left click, 2-finger drag =
scroll, 2-finger tap = right click, 3-finger tap = middle click.

## Install

```bash
git clone <this-repo> ~/asus-screenpad-ux8402
cd ~/asus-screenpad-ux8402
./install.sh
```

The installer:
1. checks/offers to apt-install deps (`brightnessctl python3-evdev python3-gi libnotify-bin`),
2. copies the scripts to `~/.local/bin`,
3. installs the udev rules and adds you to the `video` + `plugdev` groups (sudo),
4. installs + enables the `screenpad-trackpad` systemd **user** service,
5. sets the GNOME keyboard shortcuts (`./install.sh --no-keys` to skip).

**Log out and back in once** after the first install — group membership (`video`
for brightness/power, `plugdev` for touch input) only applies to new logins.

## What gets installed

| Path | Purpose |
|------|---------|
| `~/.local/bin/screenpad-brightness` | step ScreenPad brightness up/down |
| `~/.local/bin/screenpad-toggle` | enable/disable the DP-1 output + backlight via mutter D-Bus (persisted to `monitors.xml`) |
| `~/.local/bin/screenpad-trackpad` | flip the input daemon between touch/trackpad (drives the service) |
| `~/.local/bin/screenpad-trackpad-daemon` | grabs the ScreenPad touchscreen, re-injects as virtual touch/trackpad |
| `~/.local/bin/screenpad-restore` | at login, re-applies the backlight off-state if the ScreenPad was left off |
| `~/.config/systemd/user/screenpad-trackpad.service` | runs the daemon, autostarts at login |
| `~/.config/systemd/user/screenpad-restore.service` | oneshot at login, runs `screenpad-restore` |
| `/etc/udev/rules.d/90-screenpad-backlight.rules` | `video` group write access to backlight/bl_power |
| `/etc/udev/rules.d/91-screenpad-trackpad.rules` | `plugdev` access to the ELAN touchscreens + uinput |

## How the touch/trackpad part works (the non-obvious bits)

- GNOME/mutter treats **both** built-in ELAN panels as built-in touchscreens and
  maps the ScreenPad's raw touch to the **primary** display — so untouched, the
  ScreenPad's touch drives the main screen. The daemon `EVIOCGRAB`s the real
  ScreenPad touchscreen (hiding it from the compositor) and re-injects input
  through its own virtual uinput devices.
- **Absolute mode** uses a virtual touchscreen with `INPUT_PROP_DIRECT` whose
  reported physical size is forced to **309×91mm** — inside mutter's 5% size-match
  window for DP-1 (`MAX_SIZE_MATCH_DIFF = 0.05`, both axes) and far from the main
  panel — so mutter maps it to the ScreenPad. **Trackpad mode** uses a virtual
  relative pointer. `Super+F6` flips modes via `SIGUSR1`.
- The touch digitizer is powered with the panel backlight, so the toggle powers
  the panel on before switching.

### Tuning the trackpad

Set these env vars (e.g. in the keybinding command) and `systemctl --user restart screenpad-trackpad.service`:

| Var | Default | Meaning |
|-----|---------|---------|
| `SCREENPAD_TRACKPAD_GAIN` | 3000 | pixels swept across the full pad width |
| `SCREENPAD_TRACKPAD_SENS` | 1.3 | multiplier on GAIN |
| `SCREENPAD_TRACKPAD_SCROLL` | 0.02 | wheel ticks per device-unit of 2-finger drag |
| `SCREENPAD_TOUCH_NAME` | (auto) | substring to pin the ScreenPad touch device |

## Commands

```bash
screenpad-trackpad status      # daemon state + current mode
screenpad-trackpad trackpad    # force trackpad mode
screenpad-trackpad touch       # force absolute-touch mode
screenpad-trackpad restart
journalctl --user -u screenpad-trackpad.service -f
```

## Uninstall

```bash
./uninstall.sh
```

## Notes / portability

- The udev rules hard-code this model's touch controllers
  (`ELAN9008:00 04F3:2F29`, `ELAN9009:00 04F3:2F2A`) and the `asus_screenpad`
  backlight. On a different model, check `cat /proc/bus/input/devices` and
  `ls /sys/class/backlight` and adjust `udev/*.rules`.
- The 309×91mm size in the daemon is tuned to this ScreenPad's EDID. If absolute
  touch lands on the wrong screen after a panel/firmware change, re-check the
  EDID size (`/sys/class/drm/card*-DP-1/edid`) and adjust `NX/NY` in
  `bin/screenpad-trackpad-daemon`.
- Brightness on/off depends on the `asus-wmi-screenpad` kernel module providing
  `/sys/class/backlight/asus_screenpad`.
- mutter persists the ScreenPad *output* (DP-1) being off, but the panel
  `bl_power` is a kernel attribute that resets to on (`0`) every boot — so after
  a reboot the output stays disabled yet the backlight glows. The
  `screenpad-restore` login service re-applies `bl_power=1` whenever the toggle's
  off-flag (`~/.cache/screenpad-display.off`) is present, which is what keeps the
  off-state holding across reboots.
