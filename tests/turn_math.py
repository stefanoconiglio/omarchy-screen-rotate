#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["evdev>=1.7"]
# ///
"""The touchpad's turning, without a touchpad: the corners of the real pad
land where a pad turned clockwise puts them, the axes swap their ranges, and a
frame where only X or only Y moves writes the one virtual axis that changed.
Run: tests/turn_math.py (exit 0 and "ok")."""

import importlib.machinery
import importlib.util
import pathlib

from evdev import AbsInfo, ecodes as e

HERE = pathlib.Path(__file__).resolve().parent
path = str(HERE.parent / "bin" / "omarchy-screen-rotate-touchpad")
loader = importlib.machinery.SourceFileLoader("helper", path)
spec = importlib.util.spec_from_loader("helper", loader)
helper = importlib.util.module_from_spec(spec)
loader.exec_module(helper)

# A pad wider than tall, like the ELAN0731's (X 0..3200, Y 0..2000).
X = AbsInfo(value=0, min=0, max=3200, fuzz=0, flat=0, resolution=32)
Y = AbsInfo(value=0, min=0, max=2000, fuzz=0, flat=0, resolution=31)
absinfo = {e.ABS_X: X, e.ABS_Y: Y, e.ABS_MT_POSITION_X: X, e.ABS_MT_POSITION_Y: Y,
           e.ABS_MT_SLOT: AbsInfo(0, 0, 4, 0, 0, 0)}

# Turned 90° clockwise: the real top-left corner goes to the top right, the
# real bottom-left to the top-left; the real right edge becomes the bottom.
assert helper.turn(90, 0, 0, X, Y) == (2000, 0)
assert helper.turn(90, 0, 2000, X, Y) == (0, 0)
assert helper.turn(90, 3200, 2000, X, Y) == (0, 3200)
assert helper.turn(270, 0, 0, X, Y) == (0, 3200)
assert helper.turn(270, 3200, 0, X, Y) == (0, 0)
assert helper.turn(180, 0, 0, X, Y) == (3200, 2000)

# A finger moving right on the real pad (X grows) moves down on the virtual
# one turned 90°, and up-on-the-real-pad (Y falls) moves right.
a = helper.turn(90, 1000, 1000, X, Y)
b = helper.turn(90, 1100, 1000, X, Y)
assert b[1] > a[1] and b[0] == a[0]
c = helper.turn(90, 1000, 900, X, Y)
assert c[0] > a[0] and c[1] == a[1]

# The virtual axes take each other's range and resolution for 90 and 270.
v = helper.virtual_absinfo(90, absinfo)
assert v[e.ABS_X] is Y and v[e.ABS_Y] is X
assert v[e.ABS_MT_POSITION_X] is Y and v[e.ABS_MT_POSITION_Y] is X
assert v[e.ABS_MT_SLOT] is absinfo[e.ABS_MT_SLOT]
assert helper.virtual_absinfo(180, absinfo)[e.ABS_X] is X

# Frame by frame: the last value of the other axis is kept.
t = helper.Turner(90, absinfo)
assert t.events(e.EV_ABS, e.ABS_MT_POSITION_X, 1000) == [(e.EV_ABS, e.ABS_MT_POSITION_Y, 1000)]
assert t.events(e.EV_ABS, e.ABS_MT_POSITION_Y, 500) == [(e.EV_ABS, e.ABS_MT_POSITION_X, 1500)]
assert t.events(e.EV_ABS, e.ABS_X, 7) == [(e.EV_ABS, e.ABS_Y, 7)]
# Everything else goes through unchanged.
assert t.events(e.EV_ABS, e.ABS_MT_SLOT, 1) == [(e.EV_ABS, e.ABS_MT_SLOT, 1)]
assert t.events(e.EV_KEY, e.BTN_LEFT, 1) == [(e.EV_KEY, e.BTN_LEFT, 1)]
assert t.events(e.EV_SYN, e.SYN_REPORT, 0) == [(e.EV_SYN, e.SYN_REPORT, 0)]
t180 = helper.Turner(180, absinfo)
assert t180.events(e.EV_ABS, e.ABS_X, 200) == [(e.EV_ABS, e.ABS_X, 3000)]

# The touchpad is found among devices as python-evdev reports them: with
# absinfo the EV_ABS list holds (code, AbsInfo) pairs, and only absinfo=False
# gives bare codes (2 Nov 2026: the first version missed the touchpad so).
class FakeDevice:
    def __init__(self, path, name, abs_codes, keys, props):
        self.path, self.name = path, name
        self._abs, self._keys, self._props = abs_codes, keys, props

    def capabilities(self, verbose=False, absinfo=True):
        abs_list = [(c, X) for c in self._abs] if absinfo else list(self._abs)
        return {e.EV_ABS: abs_list, e.EV_KEY: list(self._keys)}

    def input_props(self):
        return self._props

    def close(self):
        pass

fakes = {
    "/dev/input/event3": FakeDevice("/dev/input/event3", "keyboard", [], [e.KEY_A], []),
    "/dev/input/event9": FakeDevice("/dev/input/event9", "touchscreen",
                                    [e.ABS_MT_POSITION_X], [e.BTN_TOOL_FINGER], [e.INPUT_PROP_DIRECT]),
    "/dev/input/event11": FakeDevice("/dev/input/event11", "ELAN0731:00 04F3:3169 Touchpad",
                                     [e.ABS_X, e.ABS_MT_POSITION_X], [e.BTN_TOOL_FINGER, e.BTN_LEFT],
                                     [e.INPUT_PROP_POINTER, e.INPUT_PROP_BUTTONPAD]),
}
helper.evdev.list_devices = lambda: list(fakes)
helper.evdev.InputDevice = lambda p: fakes[p]
found = helper.find_touchpad(None)
assert found is not None and found.path == "/dev/input/event11", found

print("ok")
