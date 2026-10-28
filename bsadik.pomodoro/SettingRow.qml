import QtQuick
import qs.Commons
import qs.Commons as Commons

// One labelled popup row: icon, label and hint on the left, a control (the
// row's child) on the right. `indent` renders it as a sub-option.
Item {
  id: row

  property string icon: ""
  property string label: ""
  property string hint: ""
  property bool dim: false
  property bool indent: false
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family
  property string iconFamily: "JetBrainsMono Nerd Font"
  default property alias control: controlSlot.data

  readonly property color muted: Qt.darker(foreground, 1.4)
  readonly property int gutter: Style.space(22)

  height: Math.max(textColumn.implicitHeight, controlSlot.height)

  Text {
    id: iconText
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: row.gutter
    visible: !row.indent
    text: row.icon
    color: row.dim ? row.muted : row.accent
    font.family: row.iconFamily
    font.pixelSize: Style.font.icon
  }

  Column {
    id: textColumn
    anchors.left: parent.left
    anchors.leftMargin: row.gutter + (row.indent ? Style.space(4) : 0)
    anchors.right: controlSlot.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: (row.indent ? "└ " : "") + row.label
      color: row.indent ? row.muted : row.foreground
      font.family: row.fontFamily
      font.pixelSize: row.indent ? Style.font.bodySmall : Style.font.body
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      visible: row.hint !== ""
      textFormat: Text.PlainText
      text: row.hint
      color: row.muted
      font.family: row.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  Item {
    id: controlSlot
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: childrenRect.width
    height: childrenRect.height
  }
}
