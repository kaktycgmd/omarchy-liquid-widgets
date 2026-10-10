import QtQuick
import qs.Commons
import qs.Ui

// Contents of the bar widget's popup: which widgets show, where they sit, and
// how they look. It emits an intent for every change; the bar widget owns the
// single write path to shell.json, so this file never touches persisted state.
Column {
  id: root

  required property var config
  // Whether the hyprglass Hyprland plugin is loaded. Purely for display: the
  // panel asks the bar widget to install it, it never runs anything itself.
  property bool glassAvailable: false

  signal widgetToggled(string id)
  signal positionPicked(string position)
  signal settingChanged(string key, real value)
  signal flagToggled(string key)
  signal clockStylePicked(string style)
  signal resetLayoutRequested()
  signal installGlassRequested()

  spacing: Style.spacing.md

  // True while the user holds a slider. The enclosing Flickable watches this so
  // it does not steal the drag out from under the knob.
  property bool sliderDragging: false

  readonly property color foreground: Color.popups.text
  readonly property color dim: Util.alpha(foreground, 0.6)
  readonly property string fontFamily: Style.font.family

  readonly property var positions: [
    "top-left", "top-center", "top-right",
    "middle-left", "", "middle-right",
    "bottom-left", "bottom-center", "bottom-right"
  ]

  readonly property var clockStyles: [
    { value: "default", label: "Big time" },
    { value: "digits", label: "Glassy digits" }
  ]

  function widgetEnabled(id) {
    return root.config.widgets.indexOf(id) !== -1
  }

  // ---- Widgets -----------------------------------------------------------
  SectionHeader { title: "Widgets" }

  Toggle {
    width: parent.width
    label: "Clock"
    description: "Time, and the date beneath it."
    checked: root.widgetEnabled("clock")
    foreground: root.foreground
    onClicked: root.widgetToggled("clock")
  }

  Toggle {
    width: parent.width
    label: "Load monitor"
    description: "CPU load, per-thread bars and memory."
    checked: root.widgetEnabled("system")
    foreground: root.foreground
    onClicked: root.widgetToggled("system")
  }

  Toggle {
    width: parent.width
    label: "Graphics card"
    description: "GPU load, VRAM and temperature."
    checked: root.widgetEnabled("gpu")
    foreground: root.foreground
    onClicked: root.widgetToggled("gpu")
  }

  Toggle {
    width: parent.width
    label: "Power profile"
    description: "The active profile, with one click to change it."
    checked: root.widgetEnabled("power")
    foreground: root.foreground
    onClicked: root.widgetToggled("power")
  }

  Toggle {
    width: parent.width
    label: "Battery"
    description: "Charge level and time remaining."
    checked: root.widgetEnabled("battery")
    foreground: root.foreground
    onClicked: root.widgetToggled("battery")
  }

  // ---- Position ----------------------------------------------------------
  SectionHeader { title: "Position"; detail: root.config.position }
  Spacer { width: parent.width }

  Grid {
    width: parent.width
    columns: 3
    spacing: Style.spacing.xs

    readonly property real cell: (width - spacing * 2) / 3

    Repeater {
      model: root.positions

      Item {
        width: parent.cell
        height: parent.cell

        Rectangle {
          anchors.fill: parent
          visible: modelData !== ""
          radius: Style.space(6)
          color: modelData === root.config.position
            ? Util.alpha(Color.accent, 0.28)
            : Util.alpha(root.foreground, posArea.containsMouse ? 0.12 : 0.05)
          border.width: Style.space(1)
          border.color: modelData === root.config.position
            ? Util.alpha(Color.accent, 0.9)
            : Util.alpha(root.foreground, 0.15)

          MouseArea {
            id: posArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.positionPicked(modelData)
          }
        }
      }
    }
  }

  // ---- Appearance --------------------------------------------------------
  SectionHeader { title: "Appearance" }
  Spacer { width: parent.width }

  LabeledSlider {
    width: parent.width
    label: "Background opacity"
    value: root.config.opacity
    minimum: 0.05
    maximum: 1
    step: 0.05
    display: Math.round(current * 100) + "%"
    onMoved: function (value) { root.settingChanged("opacity", value) }
  }

  LabeledSlider {
    width: parent.width
    label: "Default width"
    value: root.config.cardWidth
    minimum: 140
    maximum: 520
    step: 4
    integer: true
    display: Math.round(current) + " px"
    onMoved: function (value) { root.settingChanged("cardWidth", value) }
  }

  LabeledSlider {
    width: parent.width
    label: "Gap between widgets"
    value: root.config.spacing
    minimum: 0
    maximum: 48
    step: 1
    integer: true
    display: Math.round(current) + " px"
    onMoved: function (value) { root.settingChanged("spacing", value) }
  }

  LabeledSlider {
    width: parent.width
    label: "Corner radius"
    value: root.config.radius
    minimum: 0
    maximum: 64
    step: 1
    integer: true
    display: Math.round(current) + " px"
    onMoved: function (value) { root.settingChanged("radius", value) }
  }

  Toggle {
    width: parent.width
    label: "Widget titles"
    checked: root.config.showLabels
    foreground: root.foreground
    onClicked: root.flagToggled("showLabels")
  }

  Toggle {
    width: parent.width
    label: "Clock date"
    checked: root.config.showDate
    foreground: root.foreground
    onClicked: root.flagToggled("showDate")
  }

  Toggle {
    width: parent.width
    label: "Per-thread CPU bars"
    checked: root.config.showCpuCores
    foreground: root.foreground
    onClicked: root.flagToggled("showCpuCores")
  }

  // ---- Clock face --------------------------------------------------------
  SectionHeader { title: "Clock face" }

  ChoiceGrid {
    options: root.clockStyles
    selected: root.config.clockStyle
    onPicked: function (value) { root.clockStylePicked(value) }
  }

  // ---- Liquid glass ------------------------------------------------------
  SectionHeader {
    title: "Liquid glass"
    detail: root.glassAvailable ? "active" : "not installed"
  }

  Text {
    width: parent.width
    visible: root.glassAvailable
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    text: "hyprglass is active, so the cards render as real liquid glass."
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Text {
    width: parent.width
    visible: !root.glassAvailable
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    text: "The glass effect needs the hyprglass Hyprland plugin. Without it the widgets are flat translucent cards. Install it below — a terminal opens and runs hyprpm, which will ask for your password."
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Rectangle {
    width: parent.width
    visible: !root.glassAvailable
    height: Style.spacing.controlHeight + Style.space(6)
    radius: Style.space(8)
    color: Util.alpha(Color.accent, installArea.containsMouse ? 0.35 : 0.22)
    border.width: Style.space(1)
    border.color: Util.alpha(Color.accent, 0.9)

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: "Install hyprglass"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    MouseArea {
      id: installArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.installGlassRequested()
    }
  }

  // ---- Layout ------------------------------------------------------------
  SectionHeader { title: "Layout" }

  Rectangle {
    width: parent.width
    height: Style.spacing.controlHeight + Style.space(6)
    radius: Style.space(8)
    color: Util.alpha(root.foreground, resetArea.containsMouse ? 0.12 : 0.05)
    border.width: Style.space(1)
    border.color: Util.alpha(root.foreground, 0.15)

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: "Reset widget positions and sizes"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    MouseArea {
      id: resetArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.resetLayoutRequested()
    }
  }

  // ---- Inline helpers ----------------------------------------------------
  component SectionHeader: Item {
    property string title: ""
    property string detail: ""
    width: parent ? parent.width : 0
    height: Style.spacing.huge
    Text {
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      textFormat: Text.PlainText
      text: parent.title
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      font.bold: true
    }
    Text {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      textFormat: Text.PlainText
      visible: parent.detail !== ""
      text: parent.detail
      color: Util.alpha(Color.popups.text, 0.6)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  component Spacer: Rectangle {
    height: 1
    color: Util.alpha(Color.popups.text, 0.12)
  }

  component LabeledSlider: Column {
    id: sliderBlock
    property string label: ""
    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property real step: 0.05
    property bool integer: false
    property string display: ""
    signal moved(real value)

    // Every move emits, exactly like Omarchy's own slider usage: a press alone
    // commits a click, and a drag that the enclosing Flickable would otherwise
    // steal still lands. The bar widget coalesces and paces the writes, so a
    // sweep is one shell.json write rather than one per pixel. `current` keeps
    // the knob from snapping back to the config value while a write is in
    // flight through the host.
    property real current: value
    property bool dragging: false
    onValueChanged: if (!dragging) current = value
    onDraggingChanged: root.sliderDragging = dragging

    spacing: Style.spacing.xs
    width: parent ? parent.width : 0

    Row {
      width: parent.width
      spacing: Style.spacing.sm

      Text {
        id: nameText
        textFormat: Text.PlainText
        text: sliderBlock.label
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      Item {
        width: Math.max(0, parent.width - nameText.width - valueText.width)
        height: 1
      }
      Text {
        id: valueText
        textFormat: Text.PlainText
        text: sliderBlock.display
        color: Util.alpha(Color.popups.text, 0.6)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    PanelSlider {
      width: parent.width
      minimum: sliderBlock.minimum
      maximum: sliderBlock.maximum
      step: sliderBlock.step
      integer: sliderBlock.integer
      value: sliderBlock.current
      trackColor: Util.alpha(Color.popups.text, 0.15)
      fillColor: Color.accent
      knobColor: Color.popups.text
      onDraggingChanged: sliderBlock.dragging = dragging
      onMoved: function (value) {
        sliderBlock.current = value
        sliderBlock.moved(value)
      }
      onReleased: function (value) {
        sliderBlock.current = value
        sliderBlock.moved(value)
      }
    }
  }

  component ChoiceGrid: Grid {
    property var options: []
    property string selected: ""
    signal picked(string value)

    width: parent ? parent.width : 0
    columns: 2
    spacing: Style.spacing.xs

    readonly property real cell: (width - spacing * (columns - 1)) / columns

    Repeater {
      model: options

      Item {
        width: parent.cell
        height: Style.spacing.controlHeight + Style.space(6)

        Rectangle {
          anchors.fill: parent
          radius: Style.space(8)
          color: modelData.value === selected
            ? Util.alpha(Color.accent, 0.28)
            : Util.alpha(root.foreground, choiceArea.containsMouse ? 0.12 : 0.05)
          border.width: Style.space(1)
          border.color: modelData.value === selected
            ? Util.alpha(Color.accent, 0.9)
            : Util.alpha(root.foreground, 0.15)

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: modelData.label
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: modelData.value === selected
          }

          MouseArea {
            id: choiceArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: picked(modelData.value)
          }
        }
      }
    }
  }
}
