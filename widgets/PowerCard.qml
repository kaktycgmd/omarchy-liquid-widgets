import QtQuick
import qs.Commons
import "../ui"

// The power profile, as one segmented control: the active profile is highlighted
// and every offered profile is one click away.
GlassCard {
  id: root

  property var power: null

  readonly property var profiles: power ? power.profiles : []
  readonly property string active: power ? power.activeProfile : ""

  signal profileRequested(string profile)

  Text {
    width: parent.width
    visible: root.profiles.length === 0
    textFormat: Text.PlainText
    text: "No power profiles on this machine"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  Row {
    id: segmentRow
    width: parent.width
    visible: root.profiles.length > 0
    height: visible ? implicitHeight : 0
    spacing: Style.spacing.xs

    readonly property real cellWidth: (width - spacing * (root.profiles.length - 1)) / Math.max(1, root.profiles.length)

    Repeater {
      model: root.profiles

      Rectangle {
        id: segment
        width: parent.cellWidth
        height: Style.spacing.controlHeight + Style.space(6)
        radius: Style.space(8)
        color: modelData === root.active
          ? Util.alpha(root.accent, 0.28)
          : Util.alpha(root.fg, segmentArea.containsMouse ? 0.12 : 0.06)
        border.width: Style.space(1)
        border.color: modelData === root.active
          ? Util.alpha(root.accent, 0.9)
          : Util.alpha(root.fg, 0.15)

        readonly property string label: root.power ? root.power.profileLabel(modelData) : modelData

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: segment.label
          color: modelData === root.active ? root.fg : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: modelData === root.active
        }

        MouseArea {
          id: segmentArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.profileRequested(modelData)
        }
      }
    }
  }
}
