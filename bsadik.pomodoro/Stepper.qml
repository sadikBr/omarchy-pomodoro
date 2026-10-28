import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Pomodoro.js" as P

// Compact "−  15m  +" minute picker, with an optional label in front.
// Plain buttons rather than a SpinBox because bar popups don't reliably get
// keyboard focus; the wheel over the value also steps it.
Row {
  id: root

  property string label: ""
  property string zeroText: ""
  property int value: 0
  property int from: 1
  property int to: 100
  property int step: 1
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family
  property string iconFamily: "JetBrainsMono Nerd Font"

  signal modified(int value)

  function nudge(direction) {
    var next = Math.max(root.from, Math.min(root.to, root.value + direction * root.step))
    // Snap to the step grid so 5-minute steps land on 30, 35, 40…
    if (root.step > 1) next = Math.max(root.from, Math.min(root.to, Math.round(next / root.step) * root.step))
    if (next !== root.value) root.modified(next)
  }

  spacing: Style.space(4)

  Text {
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    visible: root.label !== ""
    text: root.label
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    rightPadding: Style.space(2)
  }

  Button {
    anchors.verticalCenter: parent.verticalCenter
    iconText: P.icons.minus
    iconSize: Style.font.bodySmall
    horizontalPadding: Style.space(5)
    verticalPadding: Style.space(3)
    foreground: root.foreground
    accent: root.accent
    enabled: root.value > root.from
    opacity: enabled ? 1 : 0.35
    onClicked: root.nudge(-1)
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(40)
    horizontalAlignment: Text.AlignHCenter
    textFormat: Text.PlainText
    text: root.value === 0 && root.zeroText !== "" ? root.zeroText : P.duration(root.value)
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    font.bold: true

    WheelHandler {
      onWheel: function(event) { root.nudge(event.angleDelta.y > 0 ? 1 : -1) }
    }
  }

  Button {
    anchors.verticalCenter: parent.verticalCenter
    iconText: P.icons.plus
    iconSize: Style.font.bodySmall
    horizontalPadding: Style.space(5)
    verticalPadding: Style.space(3)
    foreground: root.foreground
    accent: root.accent
    enabled: root.value < root.to
    opacity: enabled ? 1 : 0.35
    onClicked: root.nudge(1)
  }
}
