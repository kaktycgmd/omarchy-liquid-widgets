import QtQuick
import qs.Commons
import "../ui"

// CPU and memory load. The big number is CPU, because that is the reading the
// card exists for; memory sits under it, and one thin bar per thread is optional.
GlassCard {
  id: root

  property var system: null
  property bool showCores: true

  readonly property real cpuLoad: system ? system.cpuLoad : -1
  readonly property var coreLoads: system ? system.coreLoads : []
  readonly property real memFraction: system && system.memory ? system.memory.fraction : -1
  readonly property real memUsedKib: system && system.memory ? system.memory.usedKib : 0
  readonly property real memTotalKib: system && system.memory ? system.memory.totalKib : 0

  function percentText(value) {
    return value >= 0 && value <= 1 ? Math.round(value * 100) + "%" : "--"
  }

  function gib(value) {
    var n = Number(value) || 0
    return n > 0 ? (n / 1048576).toFixed(1) + " GiB" : "--"
  }

  // ---- CPU big number ----------------------------------------------------
  Row {
    width: parent.width
    spacing: Style.spacing.sm

    Text {
      textFormat: Text.PlainText
      text: "\uF4BC"
      color: root.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.icon
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      textFormat: Text.PlainText
      text: "CPU " + root.percentText(root.cpuLoad)
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Math.round(Style.font.subtitle * 1.5)
      font.bold: true
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // ---- CPU bar -----------------------------------------------------------
  Rectangle {
    width: parent.width
    height: Style.space(6)
    radius: height / 2
    color: Util.alpha(root.fg, 0.12)

    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, root.cpuLoad))
      height: parent.height
      radius: parent.radius
      color: root.accent
      Behavior on width { NumberAnimation { duration: 180 } }
    }
  }

  // ---- Per-thread bars ---------------------------------------------------
  Grid {
    id: coreGrid
    width: parent.width
    visible: root.showCores && root.coreLoads.length > 0
    height: visible ? implicitHeight : 0
    columns: Math.min(8, Math.max(1, root.coreLoads.length))
    spacing: Style.spacing.xs

    readonly property real cellWidth: (coreGrid.width - spacing * (columns - 1)) / columns

    Repeater {
      model: root.coreLoads

      Rectangle {
        width: coreGrid.cellWidth
        height: Style.space(5)
        radius: height / 2
        color: Util.alpha(root.fg, 0.12)

        Rectangle {
          width: parent.width * Math.max(0, Math.min(1, modelData))
          height: parent.height
          radius: parent.radius
          color: modelData > 0.85 ? Color.urgent : root.accent
        }
      }
    }
  }

  // ---- Memory ------------------------------------------------------------
  Text {
    width: parent.width
    textFormat: Text.PlainText
    text: "MEM  " + root.gib(root.memUsedKib) + " / " + root.gib(root.memTotalKib)
      + "   " + root.percentText(root.memFraction)
    color: root.fg
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  Rectangle {
    width: parent.width
    height: Style.space(6)
    radius: height / 2
    color: Util.alpha(root.fg, 0.12)

    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, root.memFraction))
      height: parent.height
      radius: parent.radius
      color: Color.accent
      Behavior on width { NumberAnimation { duration: 180 } }
    }
  }
}
