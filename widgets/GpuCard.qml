import QtQuick
import qs.Commons
import "../ui"

// GPU load, given a real sensor: NVIDIA through nvidia-smi, AMD/amdgpu through
// the kernel's sysfs nodes. A machine with neither (or an Intel iGPU) shows a
// plain "no sensor" line rather than a number that would never move.
GlassCard {
  id: root

  property var gpu: null

  readonly property bool present: gpu ? gpu.present : false
  readonly property real utilization: gpu ? gpu.utilization : -1
  readonly property real vramFraction: gpu ? gpu.vramFraction : -1
  readonly property real temperature: gpu ? gpu.temperature : -1
  readonly property string name: gpu && gpu.name ? gpu.name : ""

  function percentText(value) {
    return value >= 0 && value <= 1 ? Math.round(value * 100) + "%" : "--"
  }

  function gib(bytes) {
    var n = Number(bytes) || 0
    return n > 0 ? (n / 1073741824).toFixed(1) + " GiB" : "--"
  }

  Text {
    width: parent.width
    visible: !root.present
    textFormat: Text.PlainText
    text: "No GPU sensor available"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  // ---- Utilization big number -------------------------------------------
  Row {
    width: parent.width
    visible: root.present
    spacing: Style.spacing.sm

    Text {
      textFormat: Text.PlainText
      visible: root.present
      text: "\uF2DB"
      color: root.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.icon
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      textFormat: Text.PlainText
      visible: root.present
      text: "GPU " + root.percentText(root.utilization)
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Math.round(Style.font.subtitle * 1.5)
      font.bold: true
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      textFormat: Text.PlainText
      visible: root.present && root.temperature >= 0
      text: Math.round(root.temperature) + "\u00B0C"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Rectangle {
    width: parent.width
    visible: root.present
    height: visible ? Style.space(6) : 0
    radius: height / 2
    color: Util.alpha(root.fg, 0.12)

    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, root.utilization))
      height: parent.height
      radius: parent.radius
      color: root.utilization > 0.85 ? Color.urgent : root.accent
      Behavior on width { NumberAnimation { duration: 180 } }
    }
  }

  // ---- VRAM --------------------------------------------------------------
  Text {
    width: parent.width
    visible: root.present
    textFormat: Text.PlainText
    text: "VRAM  " + root.gib(root.gpu ? root.gpu.vramUsed : 0)
      + " / " + root.gib(root.gpu ? root.gpu.vramTotal : 0)
      + "   " + root.percentText(root.vramFraction)
    color: root.fg
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  Rectangle {
    width: parent.width
    visible: root.present && root.vramFraction >= 0
    height: visible ? Style.space(6) : 0
    radius: height / 2
    color: Util.alpha(root.fg, 0.12)

    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, root.vramFraction))
      height: parent.height
      radius: parent.radius
      color: Color.accent
      Behavior on width { NumberAnimation { duration: 180 } }
    }
  }
}
