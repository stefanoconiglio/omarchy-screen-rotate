#!/bin/bash
# omarchy-rotate's on, off, toggle, sync and status against stand-ins for
# hyprctl, systemctl and systemd-run: nothing on the real screen or touchpad
# moves. Checks that a touchpad that cannot be turned leaves everything
# upright (exit 4), that sync puts a half-turned state back, and that the bar
# goes to the left edge while turned and back to its own edge after.
# Run: tests/toggle_stubs.sh (exit 0 and "ok").
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROT=$HERE/../bin/omarchy-rotate
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir "$T/bin"
echo 0 >"$T/transform"; echo 0 >"$T/rotation"; echo inactive >"$T/unit"

cat >"$T/bin/hyprctl" <<EOF
#!/bin/bash
case "\$1 \$2" in
  "monitors -j") echo "[{\"name\":\"eDP-1\",\"scale\":1,\"x\":0,\"y\":0,\"transform\":\$(cat $T/transform)}]" ;;
  "getoption input:rotation") echo "{\"int\": \$(cat $T/rotation)}" ;;
  eval*)
    [[ \$2 =~ transform\ =\ ([0-9]+) ]] && echo "\${BASH_REMATCH[1]}" >$T/transform
    [[ \$2 =~ rotation\ =\ ([0-9]+) ]] && echo "\${BASH_REMATCH[1]}" >$T/rotation
    echo ok ;;
esac
EOF
cat >"$T/bin/systemctl" <<EOF
#!/bin/bash
case "\$2" in
  is-active) s=\$(cat $T/unit); echo "\$s"; [[ \$s == active ]] ;;
  stop) echo inactive >$T/unit ;;
esac
EOF
cat >"$T/bin/systemd-run" <<EOF
#!/bin/bash
[[ -e $T/fail ]] && echo failed >$T/unit || echo active >$T/unit
EOF
cat >"$T/bin/omarchy" <<EOF
#!/bin/bash
[[ "\$1 \$2" == "bar position" ]] && echo "\$3" >$T/bar
EOF
printf '#!/bin/sh\n' >"$T/bin/sleep"
chmod +x "$T"/bin/*
mkdir -p "$T/config/omarchy"
echo '{"bar": {"position": "top"}}' >"$T/config/omarchy/shell.json"
echo top >"$T/bar"
export PATH="$T/bin:$PATH" XDG_RUNTIME_DIR=$T XDG_STATE_HOME=$T/state XDG_CONFIG_HOME=$T/config

fail() { echo "FAIL: $*"; exit 1; }
st() { "$ROT" status | head -1; }

[[ $(st) == off ]] || fail "starts off"
"$ROT" toggle || fail "toggle on exits $?"
[[ $(st) == on ]] || fail "toggle turns on"
[[ $(cat "$T/transform") == 3 && $(cat "$T/rotation") == 270 ]] || fail "transform 3, rotation 270 by default"
"$ROT" status | grep -qx "touchpad active" || fail "status lists the touchpad"
"$ROT" toggle || fail "toggle off exits $?"
[[ $(st) == off ]] || fail "toggle turns off"
[[ $(cat "$T/bar") == top ]] || fail "the bar back on top"

# The bar goes left while turned and back to the edge it was on.
echo '{"bar": {"position": "bottom"}}' >"$T/config/omarchy/shell.json"; echo bottom >"$T/bar"
"$ROT" on
[[ $(cat "$T/bar") == left ]] || fail "the bar on the left while turned"
echo '{"bar": {"position": "left"}}' >"$T/config/omarchy/shell.json"
"$ROT" on   # a second on keeps the first saved edge
"$ROT" off
[[ $(cat "$T/bar") == bottom ]] || fail "the bar back to its own edge"
# A reboot while turned: upright, the bar still left, its edge saved: sync gives it back.
echo '{"bar": {"position": "bottom"}}' >"$T/config/omarchy/shell.json"
"$ROT" on
echo 0 >"$T/transform"; echo 0 >"$T/rotation"; echo inactive >"$T/unit"
[[ $("$ROT" sync) == off && $(cat "$T/bar") == bottom ]] || fail "sync gives the bar back after a reboot"

# A Hyprland reload puts the screen back: sync puts the rest back.
"$ROT" on
echo 0 >"$T/transform"
[[ $(st) == mixed ]] || fail "half turned is mixed"
[[ $("$ROT" sync) == off ]] || fail "sync puts it back"
[[ $(cat "$T/rotation") == 0 && $(cat "$T/unit") == inactive ]] || fail "sync stops touchpad and mouse"

# The other way round, too.
OMARCHY_ROTATE_TRANSFORM=1 OMARCHY_ROTATE_ANGLE=90 "$ROT" on
[[ $(cat "$T/transform") == 1 && $(cat "$T/rotation") == 90 ]] || fail "transform 1 with 90"
"$ROT" off

# The touchpad cannot be turned: nothing is, exit 4.
touch "$T/fail"
"$ROT" on 2>/dev/null; rc=$?
[[ $rc == 4 ]] || fail "touchpad failure exits 4, not $rc"
[[ $(cat "$T/transform") == 0 && $(cat "$T/rotation") == 0 ]] || fail "touchpad failure leaves the screen and mouse upright"

# Another change running: sync answers busy and changes nothing.
rm "$T/fail"
exec 9>"$T/omarchy-rotate.lock"; flock 9
[[ $("$ROT" sync) == busy ]] || fail "sync while locked is busy"
flock -u 9

"$ROT" bogus 2>/dev/null; [[ $? == 64 ]] || fail "unknown verb exits 64"
echo ok
