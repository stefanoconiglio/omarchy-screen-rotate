#!/bin/bash
# Run once, as root: sudo udev/install.sh. Installs the udev rule and the
# module line beside it, loads uinput now and applies the rule to the devices
# already there, so the user at the seat can read the touchpad and create the
# virtual one. Undo: sudo udev/install.sh --remove (then log out and in, or
# reboot, for the access to go).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
RULE=/etc/udev/rules.d/70-omarchy-screen-rotate.rules
MOD=/etc/modules-load.d/omarchy-screen-rotate.conf

if [[ ${1:-} == --remove ]]; then
  rm -f "$RULE" "$MOD"
else
  install -m 644 "$HERE/70-omarchy-screen-rotate.rules" "$RULE"
  install -m 644 "$HERE/omarchy-screen-rotate.conf" "$MOD"
  modprobe uinput
fi
udevadm control --reload
udevadm trigger --action=change --subsystem-match=input --subsystem-match=misc
udevadm settle
echo "omarchy-screen-rotate: udev rule $([[ ${1:-} == --remove ]] && echo removed || echo installed)"
