import QtQuick
import QtQuick.Effects
import qs.Commons
import "../ui"

// The time, and optionally the date.
//
// Two looks, chosen by `clockStyle`:
//   * "default" — the time set large, with the date beneath it.
//   * "digits"  — only the bare time, drawn as big translucent digits with a
//                 bright outline and an accent glow, so the numerals read as a
//                 sheet of glass on the wallpaper.
GlassCard {
  id: root

  property string timeFormat: "24h"
  property bool showDate: true
  property string clockStyle: "default"

  property date now: new Date()
  readonly property string timeText: timeFormat === "12h"
    ? Qt.formatDateTime(now, "h:mm AP")
    : Qt.formatDateTime(now, "HH:mm")
  readonly property string dateText: Qt.formatDateTime(now, "dddd, d MMMM")
  readonly property bool digitsStyle: clockStyle === "digits"

  // Declared as a property value rather than a direct child so it does not land
  // in GlassCard's visual content column.
  property Timer ticker: Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  // ---- default -----------------------------------------------------------
  Text {
    width: parent.width
    visible: !root.digitsStyle
    textFormat: Text.PlainText
    text: root.timeText
    color: root.fg
    font.family: root.fontFamily
    font.pixelSize: Math.max(Style.font.subtitle, Math.round(root.width * 0.30))
    font.bold: true
    horizontalAlignment: Text.AlignHCenter
  }

  Text {
    width: parent.width
    visible: !root.digitsStyle && root.showDate
    textFormat: Text.PlainText
    text: root.dateText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
  }

  // ---- digits ------------------------------------------------------------
  Text {
    id: digitsText
    width: parent.width
    visible: root.digitsStyle
    textFormat: Text.PlainText
    text: root.timeText
    color: Util.alpha(root.fg, 0.72)
    style: Text.Outline
    styleColor: Util.alpha("#ffffff", 0.35)
    font.family: root.fontFamily
    font.pixelSize: Math.max(Style.font.subtitle, Math.round(root.width * 0.42))
    font.bold: true
    font.letterSpacing: 2
    horizontalAlignment: Text.AlignHCenter
    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Util.alpha(Color.accent, 0.45)
      shadowBlur: 0.7
      shadowVerticalOffset: 2
      brightness: 1.05
      contrast: 1.02
    }
  }
}
