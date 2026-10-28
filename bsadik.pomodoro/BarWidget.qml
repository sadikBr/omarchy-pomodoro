import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Pomodoro.js" as P

// Bar entry for the pomodoro timer. Shows a timer glyph when idle and the
// time left while a session runs.
//
//   left click    open the popup
//   right click   start / pause / resume
//   middle click  stop
//   scroll        +/- 1 minute on the running phase
BarWidget {
  id: root
  moduleName: "bsadik.pomodoro"

  // The service is created by the shell independently of the widget, and a
  // plugin reload recreates it, so keep looking it up until it is there.
  property var service: null
  property bool popupOpen: false

  readonly property bool ready: service !== null && service.loaded === true
  readonly property string phase: ready ? service.phase : "idle"
  readonly property bool paused: ready && service.paused
  readonly property bool onBreak: phase === "micro" || phase === "break"
  readonly property bool active: phase !== "idle"

  readonly property color barColor: root.bar ? root.bar.barForeground : Commons.Color.foreground
  readonly property color fg: root.bar ? root.bar.foreground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property string iconFamily: "JetBrainsMono Nerd Font"

  readonly property bool micro: phase === "micro"
  readonly property string glyph: !active ? P.icons.timer
    : micro ? P.icons.eye
    : onBreak ? P.icons.coffee
    : paused ? P.icons.pause
    : P.icons.timer
  readonly property string label: !active ? "" : P.compact(service.remainingSeconds)
  readonly property color glyphColor: onBreak || (ready && service.finalMinute) ? accent
    : paused ? Util.alpha(barColor, 0.5)
    : barColor

  readonly property string tooltip: {
    if (!ready) return "Pomodoro"
    if (!active) return "Pomodoro · " + service.summary() + "\nRight-click to start"
    var lines = [P.phaseLabel(phase) + (paused ? " (paused)" : "") + " · " + P.clock(service.remainingSeconds) + " left"]
    if (phase === "focus" && service.next)
      lines.push((service.next.kind === "micro" ? "Micro-break" : "Long break") + " in " + P.clock(service.remainingSeconds))
    if (phase !== "break") lines.push("Block ends in " + P.compact(service.blockRemainingMs / 1000)
      + (service.microTotal > 0 ? " · micro-breaks " + service.microDone + "/" + service.microTotal : ""))
    lines.push("Today: " + service.stats.blocks + " sessions, " + P.duration(service.stats.focusMinutes) + " focused")
    return lines.join("\n")
  }

  // Shape contract for shell.summon/hide/toggle routing: the bar looks for
  // open/close/opened on the widget root and picks the copy on the focused
  // monitor (the center section also keeps a hidden placeholder copy).
  readonly property bool opened: popupOpen
  function close() { popupOpen = false }
  function open() { popupOpen = true }

  function findService() {
    if (!root.bar || !root.bar.shell) return
    var s = root.bar.shell.serviceFor(root.moduleName) || null
    if (s !== root.service) root.service = s
  }

  Timer {
    interval: root.service ? 2000 : 400
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.findService()
  }

  implicitWidth: vertical ? barSize : row.implicitWidth + Style.space(14)
  implicitHeight: vertical ? column.implicitHeight + Style.space(10) : barSize

  Row {
    id: row
    visible: !root.vertical
    anchors.centerIn: parent
    spacing: Style.space(5)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph
      color: root.glyphColor
      font.family: root.iconFamily
      font.pixelSize: Style.font.body + 1
      Behavior on color {
        enabled: !root.bar || root.bar.foregroundAnimationEnabled
        ColorAnimation { duration: 160 }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.label !== ""
      textFormat: Text.PlainText
      text: root.label
      color: root.paused ? Util.alpha(root.barColor, 0.5) : (root.onBreak ? root.accent : root.barColor)
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  Column {
    id: column
    visible: root.vertical
    anchors.centerIn: parent
    spacing: Style.space(2)

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.glyph
      color: root.glyphColor
      font.family: root.iconFamily
      font.pixelSize: Style.font.body + 1
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.label !== ""
      textFormat: Text.PlainText
      text: root.label
      color: root.onBreak ? root.accent : root.barColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  // Thin progress line along the bottom edge while a session runs.
  Rectangle {
    visible: root.active && !root.vertical
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.leftMargin: Style.space(5)
    anchors.bottomMargin: Style.space(2)
    height: Math.max(1, Style.space(2))
    radius: height / 2
    width: Math.max(0, (parent.width - Style.space(10)) * (root.ready ? root.service.progress : 0))
    color: root.onBreak ? root.accent : Util.alpha(root.barColor, root.paused ? 0.3 : 0.6)
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) { if (root.ready) root.service.toggle() }
      else if (mouse.button === Qt.MiddleButton) { if (root.ready) root.service.stop() }
      else root.popupOpen = !root.popupOpen
    }
    onWheel: function(wheel) {
      if (!root.ready || !root.active) return
      root.service.extend(wheel.angleDelta.y > 0 ? 1 : -1)
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltip)
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(380))
    contentHeight: popup.fittedContentHeight(panel.implicitHeight)

    PomodoroPanel {
      id: panel
      anchors.left: parent.left
      anchors.right: parent.right
      service: root.service
      foreground: root.fg
      accent: root.accent
      fontFamily: root.fontFamily
      iconFamily: root.iconFamily
    }
  }
}
