import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Whether the laptop's screen and touchpad are turned a quarter for
// reading while walking, from omarchy-screen-rotate (bin/omarchy-screen-rotate beside it).
// One icon at the size of Omarchy's indicators beside it, always shown: lit
// when turned, dimmed when upright, in the theme's urgent colour when only
// part is turned. `omarchy-screen-rotate sync` is run every 3 seconds: it reads the
// state and, when something is half turned (a Hyprland reload put the screen
// back), puts the rest back too.
//
// Left click turns everything when it shows upright and puts everything back
// otherwise: the click does what the tooltip said.
BarWidget {
  id: root
  moduleName: "io.github.stefanoconiglio.screen-rotate"

  // The plugin's own copy, so a plugin added with `omarchy plugin add` works
  // without the link in ~/.local/bin (which is only for the terminal).
  readonly property string rotate: decodeURIComponent(String(Qt.resolvedUrl("bin/omarchy-screen-rotate")).replace(/^file:\/\//, ""))

  // "on", "off", "mixed", or "" until the first read answers.
  property string state: ""
  readonly property bool switching: switchProc.running

  readonly property string tooltip: {
    if (switching) return state === "off" ? "Turning the screen…" : "Turning the screen back…"
    if (state === "on")
      return "Screen and touchpad turned a quarter\nClick to turn them back"
    if (state === "off")
      return "Screen upright\nClick to turn the screen and touchpad a quarter, for reading while walking"
    if (state === "mixed")
      return "Only part is turned\nClick to put everything back"
    return "Screen rotate: no answer from " + rotate + " sync"
  }

  function update(text) {
    var first = String(text || "").split("\n")[0].trim()
    if (first === "busy") return
    state = (first === "on" || first === "off" || first === "mixed") ? first : ""
  }

  function refresh() {
    if (!syncProc.running && !switchProc.running) syncProc.running = true
  }

  function toggle() {
    if (switchProc.running) return
    switchProc.running = true
  }

  implicitWidth: iconButton.implicitWidth
  implicitHeight: iconButton.implicitHeight

  IpcHandler {
    target: "io.github.stefanoconiglio.screen-rotate"

    function refresh(): void {
      root.broadcast("refresh")
    }

    // The same as a left click on the icon.
    function toggle(): void {
      root.toggle()
    }

    function state(): string {
      return JSON.stringify({ state: root.state, tooltip: root.tooltip, command: root.rotate })
    }
  }

  Process {
    id: syncProc
    command: [root.rotate, "sync"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.update(text) }
  }

  // omarchy-screen-rotate's messages go to its terminal, which a click has none of, so
  // a failure is said in a notification; the bars of every screen read again.
  // Exit 4: the touchpad could not be turned, so nothing was.
  Process {
    id: switchProc
    command: [root.rotate, "toggle"]
    onExited: function(exitCode) {
      if (exitCode === 4)
        Quickshell.execDetached(["notify-send", "-u", "critical", "Screen not turned",
          "The touchpad could not be turned, so nothing was. See: journalctl --user -u omarchy-screen-rotate-touchpad"])
      else if (exitCode !== 0)
        Quickshell.execDetached(["notify-send", "-u", "critical", "omarchy-screen-rotate failed",
          "Run omarchy-screen-rotate status in a terminal"])
      root.broadcast("refresh")
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Sized like BarIndicator (Omarchy's indicators), as Lid awake beside it.
  BarIconButton {
    id: iconButton
    anchors.fill: parent
    bar: root.bar
    text: "󰑥"
    foreground: root.state === "mixed" && root.bar ? root.bar.urgent : (root.bar ? root.bar.barForeground : Color.foreground)
    dimmed: root.state !== "on" && root.state !== "mixed"
    keepSpace: true
    useActiveColor: false
    tooltipText: root.tooltip
    fontSize: Style.font.caption
    horizontalMargin: 5
    verticalPadding: 5
    fixedWidth: root.vertical ? -1 : Style.bar.statusSlot
    fixedHeight: root.vertical ? Style.bar.statusSlot : -1
    onPressed: function(button) {
      if (button === Qt.LeftButton) root.toggle()
    }
  }
}
