# Screen rotate

An Omarchy bar button that turns the laptop's screen and its touchpad a
quarter, for reading while walking with the laptop held sideways; a second
click puts them back. It sits beside Lid awake in the middle of the
bar: lit while turned, dimmed while upright, in the urgent colour when only
part is turned (a click then puts everything back).

## What a click does

- The screen: the laptop's own panel (eDP, LVDS, DSI) gets Hyprland's
  `transform 3`; monitors that mirror it follow.
- The touchpad: it is fixed to the laptop, so it turns with it, against the
  turned picture, and must be turned back. libinput cannot rotate touchpads
  (only mice and trackballs), so `omarchy-screen-rotate-touchpad` takes the real touchpad for itself and hands
  every touch on, turned, through a virtual touchpad with the same buttons
  and properties: clicks, scrolling, gestures and palm rejection keep
  working. It runs in the user unit `omarchy-screen-rotate-touchpad.service`; when
  it stops, however it stops, the real touchpad is back.
- Mice are left alone: a mouse stays on the table, in your directions, as the
  turned picture does.
- The bar: moved to the left edge (`omarchy bar position left`), the long one
  once the screen is turned, where Omarchy's widgets take their compact
  forms; the edge it was on comes back with the screen upright.

The touchpad is turned first: if it cannot be, nothing is turned (exit 4, and
a notification from the button). Everything is set at run time, nothing in
the Hyprland config, so a Hyprland reload puts the screen upright; within 3
seconds the button notices and puts the touchpad back too.

## Install

```sh
omarchy plugin add https://github.com/stefanoconiglio/omarchy-screen-rotate --enable
sudo ~/.config/omarchy/plugins/io.github.stefanoconiglio.screen-rotate/udev/install.sh   # once: access to the touchpad and uinput
omarchy bar put io.github.stefanoconiglio.screen-rotate --section center
```

`omarchy plugin add` never runs sudo, hence the second line. For the
terminal command too:
`ln -s ~/.config/omarchy/plugins/io.github.stefanoconiglio.screen-rotate/bin/omarchy-screen-rotate ~/.local/bin/omarchy-screen-rotate`.

Or from a clone of your own, linked in:

```sh
git clone https://github.com/stefanoconiglio/omarchy-screen-rotate ~/repos/omarchy-screen-rotate
ln -s ~/repos/omarchy-screen-rotate ~/.config/omarchy/plugins/io.github.stefanoconiglio.screen-rotate
sudo ~/repos/omarchy-screen-rotate/udev/install.sh
```

then add `{ "id": "io.github.stefanoconiglio.screen-rotate" }` to the bar in
`~/.config/omarchy/shell.json` and run `omarchy restart shell`.

Needs `uv` (it fetches `python-evdev` for the touchpad helper), `jq` and
Hyprland with the Lua config.

## Remove

```sh
omarchy-screen-rotate off   # or a click, if the screen is turned
sudo ~/.config/omarchy/plugins/io.github.stefanoconiglio.screen-rotate/udev/install.sh --remove
omarchy plugin remove io.github.stefanoconiglio.screen-rotate
```

Then take `io.github.stefanoconiglio.screen-rotate` out of the bar in
`~/.config/omarchy/shell.json` (`omarchy plugin remove` leaves it there)
and remove the `~/.local/bin/omarchy-screen-rotate` link if you made one.

The udev rule (`udev/70-omarchy-screen-rotate.rules`) tags touchpads and
`/dev/uinput` with `uaccess`: the user at the seat, and nobody else, can read
the touchpad and create virtual input devices. `udev/omarchy-screen-rotate.conf`
loads `uinput` at boot. `sudo udev/install.sh --remove` takes both away.

## From a terminal

```
omarchy-screen-rotate            # toggle
omarchy-screen-rotate on|off
omarchy-screen-rotate status     # on, off or mixed; then screen, touchpad
omarchy-screen-rotate --help
```

The direction: `transform 3` with the touchpad turned 270° clockwise suits a
laptop turned a quarter anticlockwise. For the other way:
`OMARCHY_SCREEN_ROTATE_TRANSFORM=1 OMARCHY_SCREEN_ROTATE_ANGLE=90 omarchy-screen-rotate on`.

## Tests

`tests/turn_math.py` (the touchpad's coordinates, without a touchpad) and
`tests/toggle_stubs.sh` (on, off, sync and the refusal, against stand-ins for
Hyprland and systemd). Both print `ok`.

MIT licence.
