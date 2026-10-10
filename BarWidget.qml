import QtQuick
import qs.Commons
import qs.Ui
import "settings"
import "model/Settings.js" as Settings

// Bar widget entry point: the icon in the bar, and the popup that configures the
// widgets. It writes the same shell.json entry the service does (the service
// persists drag/resize); both merge over the host's settled snapshot so neither
// clobbers the other.
Panel {
  id: root

  ipcTarget: "kaktyc-liquid-widgets"
  manageIpc: false

  // The host may inject this plugin's service singleton (the object that owns
  // the desktop surface). When it does, both share one authoritative state.
  property var service: null

  // The popup keeps its own authoritative copy of the settings. The host pushes
  // `settings` back after every write, but through a file watcher that a fast
  // pair of writes can race, so the pushed value can briefly (or lastingly) lag
  // or even revert. Building each change on our own copy instead means a second
  // toggle always follows the first, no matter what the host reports.
  //
  // `config` is a plain property refreshed by refreshConfig, not a binding over
  // `shadow` and the host snapshot: adopting the host snapshot on
  // `onSettingsChanged` would otherwise re-trigger that same binding.
  property var shadow: null
  readonly property var hostConfig: Settings.normalize(service ? service.live : settings)
  property var config: hostConfig
  readonly property bool active: config.widgets.length > 0

  function refreshConfig() {
    root.config = root.shadow !== null ? root.shadow : root.hostConfig
  }

  // Writes are coalesced and paced, exactly like the service's, so a burst of
  // changes becomes one shell.json write and two writes never land close enough
  // to race the host's re-read.
  property var pendingTarget: null
  property double lastFlushMs: 0
  readonly property int writePaceMs: 300

  function write(changes) {
    var base = shadow !== null ? shadow : hostConfig
    var merged = ({})
    for (var key in base) merged[key] = base[key]
    for (var change in changes) merged[change] = changes[change]
    shadow = Settings.normalize(merged)
    refreshConfig()
    if (service && typeof service.commit === "function") {
      service.commit(changes)
      return
    }
    pendingTarget = shadow
    scheduleFlush()
  }

  function scheduleFlush() {
    var wait = Math.max(0, writePaceMs - (Date.now() - lastFlushMs))
    if (flushTimer.running && flushTimer.interval <= wait) return
    flushTimer.interval = wait
    flushTimer.restart()
  }

  function flushWrite() {
    if (pendingTarget === null) return
    if (!bar || !bar.shell || typeof bar.shell.updateEntryInline !== "function") return
    var next = pendingTarget
    pendingTarget = null
    lastFlushMs = Date.now()
    bar.shell.updateEntryInline(moduleName, next)
  }

  Timer {
    id: flushTimer
    onTriggered: root.flushWrite()
  }

  // Once nothing is pending, adopt the host's settled snapshot. The service also
  // writes to this entry (drag and resize on the desktop), so folding the host's
  // result back into `shadow` keeps a later toggle from reverting a drag.
  onSettingsChanged: if (root.pendingTarget === null && !flushTimer.running) {
    root.shadow = root.hostConfig
    root.refreshConfig()
  }

  function writeOne(key, value) {
    var change = ({})
    change[key] = value
    write(change)
  }

  function toggleWidget(id) {
    var list = config.widgets.slice()
    var at = list.indexOf(id)
    if (at === -1) list.push(id)
    else list.splice(at, 1)
    write({ widgets: list })
  }

  // The bar host re-injects `settings` as soon as they change on disk, and the
  // service reads the same entry live, so nothing needs to be pushed to it.
  // This widget is only asked to keep sampling alive while the popup is open.
  onOpenedChanged: if (service) service.panelViewing = opened
  Component.onDestruction: if (service) service.panelViewing = false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uEAFE"
    foreground: root.active ? barForeground : Qt.darker(barForeground, 1.55)
    tooltipText: root.active ? "Liquid Widgets" : "Liquid Widgets \u00b7 hidden"
    onPressed: function (pressedButton) {
      if (pressedButton === Qt.RightButton)
        root.write({ widgets: root.active ? [] : Settings.DEFAULTS.widgets.slice() })
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    popoutSwitching: root.popoutSwitching
    popoutSwitchClosing: root.popoutSwitchClosing
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // Only scroll when there is something to scroll, and never while a
        // slider is held: a scrolling Flickable would steal the drag and swallow
        // the release, so the setting would never be committed. This mirrors how
        // Omarchy's own slider panels gate their ScrollView.
        interactive: !content.sliderDragging && content.implicitHeight > flick.height

        SettingsPanel {
          id: content
          width: parent.width
          config: root.config
          onWidgetToggled: function (id) { root.toggleWidget(id) }
          onPositionPicked: function (position) { root.write({ position: position }) }
          onSettingChanged: function (key, value) { root.writeOne(key, value) }
          onFlagToggled: function (key) { root.writeOne(key, !root.config[key]) }
          onClockStylePicked: function (style) { root.writeOne("clockStyle", style) }
          onResetLayoutRequested: function () { root.write({ positions: ({}), sizes: ({}) }) }
        }
      }
    }
  }
}
