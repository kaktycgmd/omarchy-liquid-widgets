import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Ui
import "../model/Layout.js" as Layout

// The widgets on the wallpaper.
//
//   * WlrLayer.Bottom sits above the wallpaper and below every application
//     window, so the widgets are there when you look at the desktop and gone
//     when you are working.
//   * One small surface per card, anchored top-left and offset to the card's
//     own pixel position. A single full-screen surface would have to swallow
//     every click on empty wallpaper to avoid stealing the double-click
//     Omarchy uses there; one surface per card means the transparent gaps
//     between cards are not part of any surface, so those clicks pass straight
//     through.
//   * The namespace is the one hyprglass is bound to, so the translucency in
//     these cards is filled by the real liquid glass rather than painted.
Item {
  id: root

  required property var config
  required property var system
  required property var power
  required property var gpu

  property bool show: true

  signal resizePreview(string id, real w, real h)
  signal resizeCommit(string id, real w, real h)
  signal movePreview(string id, real dx, real dy)
  signal moveCommit(string id, real x, real y)
  signal profileRequested(string profile)

  readonly property var widgets: config && config.widgets ? config.widgets : []

  // Measured card sizes, keyed by widget id. Query heights on unloaded ids are
  // 0, so the stack places itself against an empty column and settles as each
  // card reports its intrinsic size.
  property var heights: ({})
  property var widths: ({})

  // Live values during a drag, before the write lands. Positions are absolute
  // screen pixels; the store only ever sees committed values.
  property var liveSizes: ({})
  property var livePositions: ({})

  function explicitSize(id) {
    if (liveSizes[id]) return liveSizes[id]
    return config && config.sizes ? config.sizes[id] : null
  }

  function cardWidth(id) {
    var size = explicitSize(id)
    return size ? size.w : config.cardWidth
  }

  function cardHeight(id) {
    var size = explicitSize(id)
    return size ? size.h : 0
  }

  // Width/height used to lay out the default stack: an explicit size wins,
  // otherwise the measured card size.
  function flowWidth(id) {
    var size = explicitSize(id)
    if (size) return size.w
    return widths[id] !== undefined ? widths[id] : config.cardWidth
  }

  function flowHeight(id) {
    var size = explicitSize(id)
    if (size) return size.h
    return heights[id] !== undefined ? heights[id] : 0
  }

  function noteMetrics(id, w, h) {
    if (widths[id] === w && heights[id] === h) return
    var nextWidths = {}
    for (var k in widths) nextWidths[k] = widths[k]
    nextWidths[id] = w
    var nextHeights = {}
    for (var j in heights) nextHeights[j] = heights[j]
    nextHeights[id] = h
    widths = nextWidths
    heights = nextHeights
  }

  // Widgets the user has dragged carry an absolute position; only the rest take
  // part in the default stack, so the stack closes up when one is moved away.
  function flowEntries() {
    var out = []
    var list = root.widgets
    for (var i = 0; i < list.length; i++) {
      var id = list[i]
      if (config.positions && config.positions[id]) continue
      out.push({ id: id, w: root.flowWidth(id), h: root.flowHeight(id) })
    }
    return out
  }

  function flowFor(screen) {
    return Layout.flowPositions(config.position, root.flowEntries(),
      config.spacing, config.marginX, config.marginY,
      screen ? screen.width : 0, screen ? screen.height : 0)
  }

  function basePositionFor(id, screen) {
    if (config.positions && config.positions[id]) return config.positions[id]
    var flow = root.flowFor(screen)
    return flow[id] || { x: config.marginX, y: config.marginY }
  }

  function positionFor(id, screen) {
    if (root.livePositions[id]) return root.livePositions[id]
    return root.basePositionFor(id, screen)
  }

  function clampPosition(id, screen, x, y) {
    var maxX = Math.max(0, (screen ? screen.width : 0) - root.flowWidth(id))
    var maxY = Math.max(0, (screen ? screen.height : 0) - root.flowHeight(id))
    return {
      x: Math.round(Math.max(0, Math.min(maxX, x))),
      y: Math.round(Math.max(0, Math.min(maxY, y)))
    }
  }

  function moveTo(id, dx, dy, screen) {
    var base = root.basePositionFor(id, screen)
    var pos = root.clampPosition(id, screen, base.x + dx, base.y + dy)
    var next = {}
    for (var k in root.livePositions) next[k] = root.livePositions[k]
    next[id] = pos
    root.livePositions = next
    return pos
  }

  // Live preview while the right button is held: move the card to the dragged
  // spot without writing anything yet.
  function showCardMove(id, dx, dy, screen) {
    root.moveTo(id, dx, dy, screen)
  }

  function commitCardMove(id, dx, dy, screen) {
    var pos = root.moveTo(id, dx, dy, screen)
    root.moveCommit(id, pos.x, pos.y)
  }

  function showCardResize(id, w, h) {
    var next = {}
    for (var k in root.liveSizes) next[k] = root.liveSizes[k]
    next[id] = { w: w, h: h }
    root.liveSizes = next
  }

  function commitCardResize(id, w, h) {
    root.showCardResize(id, w, h)
    root.resizeCommit(id, w, h)
  }

  // A live value only needs to survive until the write lands in the store. Once
  // the stored value matches it, drop it, so a later reset of positions/sizes
  // is not shadowed by a stale local override.
  function pruneLive() {
    var sizes = {}
    var sizeChanged = false
    for (var k in root.liveSizes) {
      var stored = config.sizes ? config.sizes[k] : null
      if (stored && stored.w === root.liveSizes[k].w && stored.h === root.liveSizes[k].h)
        sizeChanged = true
      else
        sizes[k] = root.liveSizes[k]
    }
    if (sizeChanged) root.liveSizes = sizes

    var positions = {}
    var positionChanged = false
    for (var p in root.livePositions) {
      var committed = config.positions ? config.positions[p] : null
      if (committed && committed.x === root.livePositions[p].x
          && committed.y === root.livePositions[p].y)
        positionChanged = true
      else
        positions[p] = root.livePositions[p]
    }
    if (positionChanged) root.livePositions = positions
  }

  onConfigChanged: {
    root.pruneLive()
    root.refreshSurfaces()
  }

  function sourceFor(id) {
    if (id === "clock") return "../widgets/ClockCard.qml"
    if (id === "system") return "../widgets/SystemCard.qml"
    if (id === "gpu") return "../widgets/GpuCard.qml"
    if (id === "power") return "../widgets/PowerCard.qml"
    if (id === "battery") return "../widgets/BatteryCard.qml"
    return ""
  }

  // Bindings rather than one-shot assignments: a change in the popup reaches a
  // live card in the same frame, with no reload.
  function configure(item, id, screen) {
    if (!item) return
    item.widgetId = id
    item.title = Layout.widgetName(id)
    item.glyph = Layout.widgetGlyph(id)
    item.showHeader = Qt.binding(function () { return root.config.showLabels })
    item.bgOpacity = Qt.binding(function () { return root.config.opacity })
    item.cardRadius = Qt.binding(function () { return root.config.radius })
    item.cardW = Qt.binding(function () { return root.cardWidth(id) })
    item.cardH = Qt.binding(function () { return root.cardHeight(id) })
    if ("system" in item) item.system = root.system
    if ("power" in item) item.power = root.power
    if ("gpu" in item) item.gpu = root.gpu
    if ("showCores" in item)
      item.showCores = Qt.binding(function () { return root.config.showCpuCores })
    if ("timeFormat" in item)
      item.timeFormat = Qt.binding(function () { return root.config.timeFormat })
    if ("clockStyle" in item)
      item.clockStyle = Qt.binding(function () { return root.config.clockStyle })
    if ("showDate" in item)
      item.showDate = Qt.binding(function () { return root.config.showDate })
    item.resizePreview.connect(function (cardId, w, h) { root.showCardResize(cardId, w, h) })
    item.resizeCommit.connect(function (cardId, w, h) { root.commitCardResize(cardId, w, h) })
    item.movePreview.connect(function (cardId, dx, dy) { root.showCardMove(cardId, dx, dy, screen) })
    item.moveCommit.connect(function (cardId, dx, dy) { root.commitCardMove(cardId, dx, dy, screen) })
    if ("profileRequested" in item)
      item.profileRequested.connect(function (profile) { root.profileRequested(profile) })
  }

  // An empty `monitor` setting means every screen. A name that matches nothing
  // yields no surface, which is the honest outcome of asking for a screen that
  // is not attached.
  readonly property var targetScreens: {
    var wanted = String(config.monitor || "")
    var all = Quickshell.screens
    if (wanted === "") return all
    var out = []
    for (var i = 0; i < all.length; i++) if (all[i] && all[i].name === wanted) out.push(all[i])
    return out
  }

  // One delegate per (screen, card). This is a plain property refreshed by
  // refreshSurfaces() rather than a binding: a binding would hand Variants a
  // brand-new array on every config change, tearing down and reloading all the
  // card windows on something as small as an opacity tick. The model is
  // rebuilt only when the set of (screen, card) pairs actually changes, which
  // is what adding, removing or moving a card to another monitor looks like.
  property var surfaces: []
  property string surfacesKey: ""

  function surfacesSignature() {
    var screens = root.targetScreens
    var list = root.widgets
    var parts = []
    for (var s = 0; s < screens.length; s++)
      for (var i = 0; i < list.length; i++)
        parts.push(String(screens[s].name) + ":" + String(list[i]))
    return parts.join("|")
  }

  function refreshSurfaces() {
    var key = root.surfacesSignature()
    if (key === root.surfacesKey) return
    root.surfacesKey = key
    var out = []
    var screens = root.targetScreens
    var list = root.widgets
    for (var s = 0; s < screens.length; s++)
      for (var i = 0; i < list.length; i++)
        out.push({ screen: screens[s], id: list[i] })
    root.surfaces = out
  }

  onWidgetsChanged: root.refreshSurfaces()
  onTargetScreensChanged: root.refreshSurfaces()
  Component.onCompleted: root.refreshSurfaces()

  Variants {
    model: root.surfaces

    PanelWindow {
      id: surface
      required property var modelData

      readonly property var screenData: modelData.screen
      readonly property string widgetId: modelData.id
      readonly property var cardPosition: root.positionFor(widgetId, screenData)

      screen: screenData
      visible: root.show && !remapGuard.remapping
      color: "transparent"

      WlrLayershell.namespace: "kaktyc-liquid-widgets"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Normal
      exclusiveZone: 0

      anchors {
        top: true
        left: true
      }

      margins {
        top: surface.cardPosition.y
        left: surface.cardPosition.x
      }

      implicitWidth: cardLoader.item ? cardLoader.item.width : root.cardWidth(widgetId)
      implicitHeight: cardLoader.item ? cardLoader.item.height : 0

      onImplicitWidthChanged: root.noteMetrics(widgetId, implicitWidth, implicitHeight)
      onImplicitHeightChanged: root.noteMetrics(widgetId, implicitWidth, implicitHeight)
      Component.onCompleted: root.noteMetrics(widgetId, implicitWidth, implicitHeight)

      ScreenMoveRemap {
        id: remapGuard
        window: surface
      }

      Loader {
        id: cardLoader
        source: root.sourceFor(surface.widgetId)
        onLoaded: root.configure(item, surface.widgetId, surface.screenData)
      }
    }
  }
}
