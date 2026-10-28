import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Pomodoro.js" as P

// Horizontal map of one session: focus stretches, micro-breaks and the long
// break, drawn to scale, with the elapsed part filled in. When idle it
// previews the configured schedule.
Item {
  id: root

  property var service: null
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property int barHeight: Math.max(6, Style.space(8))

  readonly property bool live: service !== null && service.active
  readonly property var segments: !service ? []
    : live ? service.segments : P.buildSchedule(0, service.config)
  readonly property real origin: segments.length > 0 ? segments[0].start : 0
  readonly property real total: segments.length > 0 ? segments[segments.length - 1].end - origin : 1
  readonly property real elapsed: live ? Math.max(0, service.clockNow - origin) : 0

  implicitHeight: barHeight

  Repeater {
    model: root.segments

    Item {
      id: seg
      required property var modelData
      required property int index

      readonly property real segStart: modelData.start - root.origin
      readonly property real segLen: modelData.end - modelData.start
      readonly property real done: Math.max(0, Math.min(1, (root.elapsed - segStart) / segLen))
      readonly property color base: modelData.kind === "focus" ? root.foreground : root.accent
      readonly property real gap: Math.max(1, Style.space(2))

      x: root.width * segStart / root.total
      width: Math.max(2, root.width * segLen / root.total - (index < root.segments.length - 1 ? gap : 0))
      height: root.barHeight
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.fill: parent
        radius: Math.min(height / 2, Style.cornerRadius)
        color: Util.alpha(seg.base, seg.modelData.kind === "focus" ? 0.14 : 0.3)
      }

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * seg.done
        radius: Math.min(height / 2, Style.cornerRadius)
        color: Util.alpha(seg.base, seg.modelData.kind === "focus" ? 0.75 : 1)
      }
    }
  }
}
