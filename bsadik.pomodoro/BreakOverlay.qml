import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Pomodoro.js" as P

// Full-screen break surface for one monitor. It sits on the overlay layer
// with exclusive keyboard focus, so windows underneath get neither clicks nor
// keys until the break ends or is skipped.
PanelWindow {
  id: win

  required property var service

  readonly property bool shown: service && service.overlayVisible
  readonly property bool strict: service ? service.settings.strictOverlay === true : false
  readonly property bool autoRepeat: service ? service.settings.autoRepeat === true : false
  readonly property bool micro: service ? service.phase === "micro" : false
  readonly property string idea: service && service.current ? P.idea(service.phase, Math.floor(service.current.start / 60000)) : ""
  readonly property string backgroundPath: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"

  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property color muted: Util.alpha(foreground, 0.6)
  property string fontFamily: Style.font.family
  property string iconFamily: "JetBrainsMono Nerd Font"

  property bool escArmed: false

  visible: shown || content.opacity > 0.01
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "bsadik-pomodoro"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  onShownChanged: {
    escArmed = false
    holdArea.holding = false
    if (shown) Qt.callLater(function() { keys.forceActiveFocus() })
  }

  Item {
    id: content
    anchors.fill: parent
    opacity: win.shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

    Rectangle {
      anchors.fill: parent
      color: Commons.Color.background
    }

    Image {
      id: wallpaper
      anchors.fill: parent
      source: win.visible ? Util.fileUrl(win.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
      visible: false
    }

    MultiEffect {
      anchors.fill: parent
      source: wallpaper
      visible: wallpaper.status === Image.Ready
      autoPaddingEnabled: false
      blurEnabled: true
      blur: 1.0
      blurMax: 96
      blurMultiplier: 1.2
      saturation: -0.2
    }

    Rectangle {
      anchors.fill: parent
      color: Util.alpha(Commons.Color.background, 0.72)
    }

    // Swallow every pointer event so nothing reaches the windows below.
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.AllButtons
      onClicked: keys.forceActiveFocus()
      onWheel: function(wheel) { wheel.accepted = true }
    }

    Item {
      id: keys
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        event.accepted = true
        if (event.key !== Qt.Key_Escape || win.strict) return
        if (win.escArmed) {
          win.escArmed = false
          win.service.skipBreak()
        } else {
          win.escArmed = true
          escDisarm.restart()
        }
      }
    }

    Timer {
      id: escDisarm
      interval: 3000
      onTriggered: win.escArmed = false
    }

    Column {
      id: column
      anchors.centerIn: parent
      spacing: Style.space(22)
      width: Math.min(parent.width - Style.space(64), Style.space(640))

      scale: win.shown ? 1 : 0.96
      Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: win.micro ? P.icons.eye : P.icons.coffee
        color: win.accent
        font.family: win.iconFamily
        font.pixelSize: Style.space(56)
      }

      Column {
        width: parent.width
        spacing: Style.space(6)

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: win.micro ? "Micro-break" : "Time for a long break"
          color: win.foreground
          font.family: win.fontFamily
          font.pixelSize: Style.font.displayLarge + Style.space(8)
          font.bold: true
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: !win.service ? ""
            : win.micro ? "Micro-break " + (win.service.microDone + 1) + " of " + win.service.microTotal + ". Rest your eyes and move a little."
            : "Focus block done. Step away from the screen."
          color: win.muted
          font.family: win.fontFamily
          font.pixelSize: Style.font.title
          wrapMode: Text.WordWrap
        }
      }

      Item {
        id: ringBox
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(320)
        height: width

        Canvas {
          id: ring
          anchors.fill: parent
          property real progress: win.service ? win.service.progress : 0
          property color trackColor: Util.alpha(win.foreground, 0.12)
          property color fillColor: win.accent
          onProgressChanged: requestPaint()
          onFillColorChanged: requestPaint()
          onWidthChanged: requestPaint()

          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var lw = Math.max(4, width * 0.035)
            var r = (Math.min(width, height) - lw) / 2
            var cx = width / 2
            var cy = height / 2
            ctx.lineWidth = lw
            ctx.lineCap = "round"
            ctx.strokeStyle = trackColor
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.stroke()
            // Drains clockwise from the top as the break runs out.
            var left = 1 - progress
            if (left > 0.001) {
              ctx.strokeStyle = fillColor
              ctx.beginPath()
              ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * left)
              ctx.stroke()
            }
          }
        }

        Column {
          anchors.centerIn: parent
          spacing: Style.space(2)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: win.service ? P.clock(win.service.remainingSeconds) : ""
            color: win.foreground
            font.family: win.fontFamily
            font.pixelSize: Style.space(80)
            font.bold: true
            font.features: { "tnum": 1 }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: win.service ? "of " + P.duration(win.service.phaseDuration / 60000) + (win.micro ? " micro-break" : " break") : ""
            color: win.muted
            font.family: win.fontFamily
            font.pixelSize: Style.font.subtitle
          }
        }
      }

      BorderSurface {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(column.width, ideaRow.implicitWidth + Style.space(32))
        height: ideaRow.implicitHeight + Style.space(20)
        radius: Style.cornerRadius
        color: Util.alpha(win.foreground, 0.06)
        borderSpec: Border.controlSpec("normal", win.foreground, win.accent)

        Row {
          id: ideaRow
          anchors.centerIn: parent
          spacing: Style.space(10)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: P.icons.fire
            color: win.accent
            font.family: win.iconFamily
            font.pixelSize: Style.font.iconLarge
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: win.idea
            color: win.foreground
            font.family: win.fontFamily
            font.pixelSize: Style.font.title
          }
        }
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: !win.service ? ""
          : win.micro
            ? "Back to focus after this · " + P.compact(win.service.blockRemainingMs / 1000) + " left in the block"
            : win.autoRepeat
              ? "The next focus block starts automatically"
              : "The timer stops after this break"
        color: win.muted
        font.family: win.fontFamily
        font.pixelSize: Style.font.body
      }

      Timeline {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, Style.space(420))
        service: win.service
        foreground: win.foreground
        accent: win.accent
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(10)

        Button {
          iconText: P.icons.plus
          text: "1 min"
          bordered: true
          foreground: win.foreground
          accent: win.accent
          fontSize: Style.font.subtitle
          horizontalPadding: Style.space(16)
          verticalPadding: Style.space(10)
          onClicked: win.service.extend(1)
        }

        // Skip: a click normally, a 3 second hold in strict mode.
        BorderSurface {
          id: skipButton
          width: skipRow.implicitWidth + Style.space(32)
          height: skipRow.implicitHeight + Style.space(20)
          radius: Style.cornerRadius
          color: holdArea.containsMouse ? Style.hoverFillFor(win.foreground, win.accent) : Style.normalFillFor(win.foreground, win.accent)
          borderSpec: Border.controlSpec(holdArea.containsMouse ? "hover-cursor" : "normal", win.foreground, win.accent)
          clip: true

          Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * holdArea.holdProgress
            color: Util.alpha(win.accent, 0.35)
            radius: Style.cornerRadius
          }

          Row {
            id: skipRow
            anchors.centerIn: parent
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: P.icons.skip
              color: win.foreground
              font.family: win.iconFamily
              font.pixelSize: Style.font.icon
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: win.strict ? (holdArea.holding ? "Keep holding…" : "Hold to skip break") : "Skip break"
              color: win.foreground
              font.family: win.fontFamily
              font.pixelSize: Style.font.subtitle
            }
          }

          MouseArea {
            id: holdArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            property bool holding: false
            property real holdProgress: 0

            onPressed: if (win.strict) holding = true
            onReleased: holding = false
            onCanceled: holding = false
            onClicked: if (!win.strict) win.service.skipBreak()
            onHoldingChanged: if (!holding) holdProgress = 0

            NumberAnimation on holdProgress {
              running: holdArea.holding
              from: 0
              to: 1
              duration: 3000
              onFinished: {
                if (holdArea.holding) {
                  holdArea.holding = false
                  win.service.skipBreak()
                }
              }
            }
          }
        }

        Button {
          iconText: P.icons.stop
          text: "Stop timer"
          bordered: true
          visible: !win.strict
          foreground: win.foreground
          accent: win.accent
          fontSize: Style.font.subtitle
          horizontalPadding: Style.space(16)
          verticalPadding: Style.space(10)
          onClicked: win.service.stop()
        }
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: win.strict ? "Strict mode: hold the button for 3 seconds to skip"
          : (win.escArmed ? "Press Esc again to skip the break" : "Press Esc twice to skip")
        color: win.escArmed ? win.accent : Util.alpha(win.foreground, 0.4)
        font.family: win.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }
}
