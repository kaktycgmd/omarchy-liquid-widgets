import QtQuick
import qs.Commons
import "../ui"

// Battery state from UPower: percentage, charge direction and time remaining.
GlassCard {
  id: root

  property var power: null

  readonly property bool present: power ? power.present : false
  readonly property bool charging: power ? power.charging : false
  readonly property bool fullyCharged: power ? power.fullyCharged : false
  readonly property real fraction: power ? power.fraction : -1
  readonly property real secondsRemaining: power ? power.secondsRemaining : 0
  readonly property bool low: power ? power.low : false

  function percentText() {
    return root.present && root.fraction >= 0 ? Math.round(root.fraction * 100) + "%" : "--"
  }

  function remainingText() {
    if (!root.present) return "No battery"
    if (root.fullyCharged) return "Fully charged"
    var s = Math.max(0, Math.round(root.secondsRemaining))
    if (s <= 0) return root.charging ? "Charging" : "On battery"
    var h = Math.floor(s / 3600)
    var m = Math.floor((s % 3600) / 60)
    var span = (h > 0 ? h + "h " : "") + m + "m"
    return root.charging ? span + " to full" : span + " left"
  }

  Row {
    width: parent.width
    spacing: Style.spacing.sm

    Text {
      textFormat: Text.PlainText
      text: root.power ? root.power.icon : "\uF240"
      color: root.low ? Color.urgent : root.accent
      font.family: root.fontFamily
      font.pixelSize: Math.round(Style.font.icon * 1.4)
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      textFormat: Text.PlainText
      text: root.percentText()
      color: root.low ? Color.urgent : root.fg
      font.family: root.fontFamily
      font.pixelSize: Math.round(Style.font.subtitle * 1.7)
      font.bold: true
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Rectangle {
    width: parent.width
    height: Style.space(6)
    radius: height / 2
    color: Util.alpha(root.fg, 0.12)

    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, root.fraction))
      height: parent.height
      radius: parent.radius
      color: root.low ? Color.urgent : root.accent
      Behavior on width { NumberAnimation { duration: 180 } }
    }
  }

  Text {
    width: parent.width
    textFormat: Text.PlainText
    text: root.remainingText()
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }
}
