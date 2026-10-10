import QtQuick
import qs.Commons

// Chrome shared by every liquid widget.
//
// Colours, radius and type come from the active Omarchy theme's own singletons,
// so a theme switch restyles these cards in the same frame as the rest of the
// shell. The background is deliberately translucent: with the hyprglass
// Hyprland plugin bound to this surface's namespace, what shows through is the
// real liquid glass, not a painted imitation.
Rectangle {
  id: root

  property string widgetId: ""
  property string title: ""
  property string glyph: ""
  property string meta: ""
  property bool showHeader: true
  property real bgOpacity: 0.35
  property int cardRadius: 22
  property real cardW: 240
  // 0 means "as tall as the content"; a resize writes an explicit height.
  property real cardH: 0
  property bool resizable: true

  signal resizePreview(string id, real w, real h)
  signal resizeCommit(string id, real w, real h)
  signal movePreview(string id, real dx, real dy)
  signal moveCommit(string id, real dx, real dy)

  readonly property color fg: Color.popups.text
  readonly property color dim: Util.alpha(fg, 0.55)
  readonly property color accent: Color.accent
  readonly property string fontFamily: Style.font.family
  readonly property int pad: Style.spacing.panelPadding

  default property alias content: column.children

  // Right-button drag moves the whole card. Declared as a property value, not a
  // direct child, so it does not land in the content column; declared before the
  // column so it sits behind the content, which keeps button hover and clicks
  // working while a right press on any other spot still reaches this area.
  // The offset is measured in global coordinates, so the card moving under the
  // cursor does not feed back into its own drag.
  property MouseArea dragArea: MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.SizeAllCursor

    property point startGlobal: Qt.point(0, 0)

    onPressed: function (mouse) {
      startGlobal = dragArea.mapToGlobal(mouse.x, mouse.y)
    }

    onPositionChanged: function (mouse) {
      if (!pressed) return
      var now = dragArea.mapToGlobal(mouse.x, mouse.y)
      root.movePreview(root.widgetId, now.x - startGlobal.x, now.y - startGlobal.y)
    }

    onReleased: function (mouse) {
      var now = dragArea.mapToGlobal(mouse.x, mouse.y)
      root.moveCommit(root.widgetId, now.x - startGlobal.x, now.y - startGlobal.y)
    }
  }

  width: cardW
  height: cardH > 0 ? cardH : implicitHeight
  implicitWidth: cardW
  implicitHeight: column.implicitHeight + pad * 2
  radius: cardRadius
  color: Util.alpha(Color.popups.background, bgOpacity)
  border.width: Style.space(1)
  border.color: Util.alpha(Color.popups.border, 0.5)
  clip: false

  Column {
    id: column
    x: root.pad
    y: root.pad
    width: root.width - root.pad * 2
    spacing: Style.spacing.md

    Row {
      id: header
      visible: root.showHeader
      width: parent.width
      height: visible ? implicitHeight : 0
      spacing: Style.spacing.sm

      Text {
        textFormat: Text.PlainText
        visible: root.glyph !== ""
        text: root.glyph
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        anchors.verticalCenter: titleText.verticalCenter
      }

      Text {
        id: titleText
        textFormat: Text.PlainText
        width: parent.width - (root.glyph !== "" ? Style.font.icon + parent.spacing : 0)
          - (metaText.visible ? metaText.implicitWidth + parent.spacing : 0)
        text: root.title
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        id: metaText
        textFormat: Text.PlainText
        visible: root.meta !== ""
        text: root.meta.toUpperCase()
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.1
      }
    }
  }

  // Corner resize grip. The delta is measured in global coordinates so the card
  // growing under the cursor does not feed back into its own drag.
  MouseArea {
    id: grip
    visible: root.resizable
    width: Style.space(20)
    height: Style.space(20)
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    cursorShape: Qt.SizeFDiagCursor
    acceptedButtons: Qt.LeftButton

    property real startW: 0
    property real startH: 0
    property point startGlobal: Qt.point(0, 0)

    onPressed: function (mouse) {
      startW = root.cardW
      startH = root.cardH > 0 ? root.cardH : root.implicitHeight
      startGlobal = grip.mapToGlobal(mouse.x, mouse.y)
    }

    onPositionChanged: function (mouse) {
      if (!pressed) return
      var now = grip.mapToGlobal(mouse.x, mouse.y)
      var w = Math.max(Style.space(140), startW + (now.x - startGlobal.x))
      var h = Math.max(Style.space(80), startH + (now.y - startGlobal.y))
      root.resizePreview(root.widgetId, Math.round(w), Math.round(h))
    }

    onReleased: function (mouse) {
      var now = grip.mapToGlobal(mouse.x, mouse.y)
      var w = Math.max(Style.space(140), startW + (now.x - startGlobal.x))
      var h = Math.max(Style.space(80), startH + (now.y - startGlobal.y))
      root.resizeCommit(root.widgetId, Math.round(w), Math.round(h))
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.space(5)
      color: "transparent"
      radius: Style.space(3)
      border.width: Style.space(1)
      border.color: Util.alpha(root.fg, grip.containsMouse || grip.pressed ? 0.6 : 0.22)
    }
  }
}
