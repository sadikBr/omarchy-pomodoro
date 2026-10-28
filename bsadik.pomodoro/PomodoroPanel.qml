import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Pomodoro.js" as P

// Popup body: live status and session timeline, transport controls, the
// session setup (focus block, micro-breaks, long break), options, and today's
// totals.
Column {
  id: root

  property var service: null
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family
  property string iconFamily: "JetBrainsMono Nerd Font"

  readonly property bool ready: service !== null && service.loaded === true
  readonly property string phase: ready ? service.phase : "idle"
  readonly property bool active: ready && service.active
  readonly property bool onBreak: phase === "micro" || phase === "break"
  readonly property bool paused: ready && service.paused
  readonly property var config: ready ? service.config : P.defaults().config
  readonly property color muted: Qt.darker(foreground, 1.4)

  spacing: Style.space(12)

  // ------------------------------------------------------------ status

  Item {
    width: parent.width
    height: statusColumn.implicitHeight

    Column {
      id: statusColumn
      anchors.left: parent.left
      anchors.right: phaseBadge.left
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(2)

      Text {
        textFormat: Text.PlainText
        text: !root.ready ? "--:--"
          : root.active ? P.clock(root.service.remainingSeconds)
          : P.clock(root.config.block * 60)
        color: root.active ? (root.onBreak ? root.accent : root.foreground) : root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.display + Style.space(8)
        font.bold: true
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: {
          if (!root.ready) return "Loading…"
          var s = root.service
          if (!root.active) return "Ready · " + P.duration(root.config.block) + " focus block"
          if (root.phase === "micro") return "Micro-break " + (s.microDone + 1) + " of " + s.microTotal
          if (root.phase === "break") return "Long break · session " + (s.blockNumber + 1) + " done"
          var nextText = s.next ? (s.next.kind === "micro" ? "micro-break" : "long break") + " after this" : "last stretch"
          return (root.paused ? "Paused · " : "Focus · ") + nextText
        }
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }

    BorderSurface {
      id: phaseBadge
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(44)
      height: width
      radius: Style.cornerRadius > 0 ? width / 2 : 0
      color: root.active ? Util.alpha(root.accent, 0.18) : Style.normalFillFor(root.foreground, root.accent)
      borderSpec: Border.controlSpec(root.active ? "selected" : "normal", root.foreground, root.accent)

      Text {
        anchors.centerIn: parent
        text: root.phase === "micro" ? P.icons.eye
          : root.phase === "break" ? P.icons.coffee
          : root.paused ? P.icons.pause
          : root.active ? P.icons.brain : P.icons.timer
        color: root.active ? root.accent : root.foreground
        font.family: root.iconFamily
        font.pixelSize: Style.font.iconLarge + Style.space(2)
      }
    }
  }

  Column {
    width: parent.width
    spacing: Style.space(5)

    Timeline {
      width: parent.width
      service: root.service
      foreground: root.foreground
      accent: root.accent
    }

    Item {
      width: parent.width
      height: blockText.implicitHeight

      Text {
        id: blockText
        anchors.left: parent.left
        textFormat: Text.PlainText
        text: !root.ready ? ""
          : root.active && root.phase !== "break"
            ? "Block ends in " + P.compact(root.service.blockRemainingMs / 1000)
            : root.active ? "Block complete" : root.service.summary()
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.right: parent.right
        visible: root.ready && root.service.microTotal > 0 && root.active
        textFormat: Text.PlainText
        text: root.ready ? root.service.microDone + "/" + root.service.microTotal + " micro-breaks" : ""
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // ---------------------------------------------------------- controls

  Row {
    width: parent.width
    spacing: Style.space(6)

    readonly property real cell: (width - spacing * 3) / 4

    Button {
      width: parent.cell
      iconText: !root.active || root.paused ? P.icons.play : P.icons.pause
      text: !root.active ? "Start" : (root.paused ? "Resume" : "Pause")
      tooltipText: "Right-click the bar icon to do this too"
      bordered: true
      selected: !root.active
      enabled: root.ready && !root.onBreak
      opacity: enabled ? 1 : 0.4
      foreground: root.foreground
      accent: root.accent
      onClicked: root.service.toggle()
    }

    Button {
      width: parent.cell
      iconText: root.onBreak ? P.icons.skip : P.icons.coffee
      text: root.onBreak ? "Skip" : "Break"
      tooltipText: root.onBreak ? "Skip this break" : "Take the next break now"
      bordered: true
      enabled: root.active
      opacity: enabled ? 1 : 0.4
      foreground: root.foreground
      accent: root.accent
      onClicked: root.service.skip()
    }

    Button {
      width: parent.cell
      iconText: P.icons.plus
      text: "5m"
      tooltipText: "Add 5 minutes (scroll on the bar icon for ±1)"
      bordered: true
      enabled: root.active
      opacity: enabled ? 1 : 0.4
      foreground: root.foreground
      accent: root.accent
      onClicked: root.service.extend(5)
    }

    Button {
      width: parent.cell
      iconText: P.icons.stop
      text: "Stop"
      tooltipText: "Stop the timer (middle-click the bar icon)"
      bordered: true
      enabled: root.active
      opacity: enabled ? 1 : 0.4
      foreground: root.foreground
      accent: root.accent
      onClicked: root.service.stop()
    }
  }

  PanelSeparator { width: parent.width; foreground: root.foreground }

  // ------------------------------------------------------------ session

  PanelSectionHeader {
    text: "Session"
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Column {
    width: parent.width
    spacing: Style.space(8)

    SettingRow {
      foreground: root.foreground
      accent: root.accent
      fontFamily: root.fontFamily
      iconFamily: root.iconFamily
      width: parent.width
      icon: P.icons.brain
      label: "Focus block"
      hint: "Total length, micro-breaks included"
      Stepper {
        value: root.config.block
        from: P.limits.block[0]
        to: P.limits.block[1]
        step: 5
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        onModified: function(v) { root.service.setConfig("block", v) }
      }
    }

    SettingRow {
      foreground: root.foreground
      accent: root.accent
      fontFamily: root.fontFamily
      iconFamily: root.iconFamily
      width: parent.width
      icon: P.icons.eye
      label: "Micro-breaks"
      hint: root.config.microEnabled
        ? P.countMicro(root.config) + " short breaks inside the block"
        : "Off"
      dim: !root.config.microEnabled
      ToggleSwitch {
        checked: root.config.microEnabled
        foreground: root.foreground
        accent: root.accent
        interactive: root.ready
        onToggled: root.service.setConfig("microEnabled", !root.config.microEnabled)
      }
    }

    SettingRow {
      foreground: root.foreground
      accent: root.accent
      fontFamily: root.fontFamily
      iconFamily: root.iconFamily
      width: parent.width
      visible: root.config.microEnabled
      indent: true
      label: "Every"
      Stepper {
        value: root.config.microEvery
        from: P.limits.microEvery[0]
        to: P.limits.microEvery[1]
        step: value >= 30 ? 5 : 1
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        onModified: function(v) { root.service.setConfig("microEvery", v) }
      }
    }

    SettingRow {
      foreground: root.foreground
      accent: root.accent
      fontFamily: root.fontFamily
      iconFamily: root.iconFamily
      width: parent.width
      visible: root.config.microEnabled
      indent: true
      label: "For"
      Stepper {
        value: root.config.microLength
        from: P.limits.microLength[0]
        to: P.limits.microLength[1]
        step: 1
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        onModified: function(v) { root.service.setConfig("microLength", v) }
      }
    }

    SettingRow {
      foreground: root.foreground
      accent: root.accent
      fontFamily: root.fontFamily
      iconFamily: root.iconFamily
      width: parent.width
      icon: P.icons.coffee
      label: "Long break"
      hint: "After the focus block"
      Stepper {
        value: root.config.longBreak
        from: P.limits.longBreak[0]
        to: P.limits.longBreak[1]
        step: value >= 20 ? 5 : 1
        zeroText: "Off"
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        onModified: function(v) { root.service.setConfig("longBreak", v) }
      }
    }

    Text {
      width: parent.width
      visible: root.active
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      text: "Changes apply from the next session."
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  PanelSeparator { width: parent.width; foreground: root.foreground }

  // ----------------------------------------------------------- options

  PanelSectionHeader {
    text: "Options"
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Column {
    width: parent.width
    spacing: Style.space(8)

    Repeater {
      model: [
        { key: "autoRepeat", icon: P.icons.repeat, label: "Keep going", hint: "Start the next session after the long break" },
        { key: "warnBeforeBreak", icon: P.icons.bell, label: "Warn before long break", hint: "Notify one minute ahead" },
        { key: "sounds", icon: P.icons.volume, label: "Sounds", hint: "Chime when breaks start and end" },
        { key: "strictOverlay", icon: P.icons.shield, label: "Strict breaks", hint: "Hold 3 s to skip, no Esc or Stop" }
      ]

      SettingRow {
      foreground: root.foreground
      accent: root.accent
      fontFamily: root.fontFamily
      iconFamily: root.iconFamily
      width: parent.width
        id: optionRow
        required property var modelData
        readonly property bool checked: root.ready && root.service.settings[modelData.key] === true

        icon: modelData.icon
        label: modelData.label
        hint: modelData.hint
        dim: !checked

        ToggleSwitch {
          checked: optionRow.checked
          foreground: root.foreground
          accent: root.accent
          interactive: root.ready
          onToggled: root.service.setSetting(optionRow.modelData.key, !optionRow.checked)
        }
      }
    }
  }

  PanelSeparator { width: parent.width; foreground: root.foreground }

  // ------------------------------------------------------------- today

  Item {
    width: parent.width
    height: Math.max(statsRow.implicitHeight, resetButton.implicitHeight)

    Row {
      id: statsRow
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(12)

      Repeater {
        model: root.ready ? [
          { icon: P.icons.flag, value: String(root.service.stats.blocks), label: root.service.stats.blocks === 1 ? "session" : "sessions" },
          { icon: P.icons.brain, value: P.duration(root.service.stats.focusMinutes), label: "focused" },
          { icon: P.icons.eye, value: String(root.service.stats.microBreaks), label: "micro" },
          { icon: P.icons.skip, value: String(root.service.stats.breaksSkipped), label: "skipped" }
        ] : []

        Row {
          required property var modelData
          spacing: Style.space(4)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.icon
            color: root.accent
            font.family: root.iconFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: modelData.value
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: modelData.label
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }

    Button {
      id: resetButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      iconText: P.icons.reset
      tooltipText: "Reset today's stats"
      foreground: root.foreground
      accent: root.accent
      enabled: root.ready
      onClicked: root.service.resetStats()
    }
  }
}
