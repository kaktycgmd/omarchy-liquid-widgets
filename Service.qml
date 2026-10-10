import QtQuick
import "services"
import "surfaces"
import "model/Settings.js" as Settings

// The plugin's single long-lived instance: it owns every sampler, holds the
// desktop surface, and is what the bar widget reads from.
//
// It is also the single source of truth for the settings. Consumers read `live`
// — the plugin's own committed state once it has written anything, otherwise
// the host's snapshot — so a change reaches the popup and the widgets the moment
// it is committed, and a second change always builds on the first.
//
// Two things can originate a write: the popup (owned by the bar widget) and a
// drag on the desktop surface (owned here). Both end up in the same shell.json
// entry, and both merge over `live`, so neither clobbers the other's fields.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "kaktyc.liquid-widgets"

  readonly property var config: Settings.normalize(shell
    ? Settings.fromBarConfig(shell.barConfig, pluginId)
    : ({}))

  // The authoritative settings every consumer should read: the plugin's own
  // committed state once it has written anything, otherwise the host's value.
  // Keeping it a plain property (refreshed by refreshLive) rather than a binding
  // avoids a binding loop: `shadow` is adopted from `config` when idle, so a
  // binding that read both would be re-triggered by its own write.
  property var shadow: null
  property var live: config
  function refreshLive() {
    root.live = root.shadow !== null ? root.shadow : root.config
  }

  // Set by the popup while it is open, so sampling keeps running then.
  property bool panelViewing: false

  readonly property bool sampling: live.widgets.length > 0 || panelViewing
  readonly property int effectiveIntervalMs: panelViewing
    ? Math.min(1000, live.intervalMs) : live.intervalMs

  readonly property alias system: systemService
  readonly property alias power: powerService
  readonly property alias gpu: gpuService

  signal resizeCommitted(string id, real w, real h)
  signal positionCommitted(string id, real x, real y)

  // Merge a partial change over `live` and persist the whole entry. The host
  // rewrites the entry wholesale, so sending the full object keeps every other
  // field intact.
  //
  // Writes are coalesced and paced. The host persists our entry and then
  // re-reads shell.json through a file watcher; two shell.json writes in quick
  // succession race that re-read, the live config reverts to the earlier value,
  // and the later change is lost — changing a setting twice used to drop one.
  // So `shadow` holds the authoritative full settings the plugin is converging
  // on, and it is flushed at most once per `writePaceMs`. An isolated change
  // (nothing recently written) goes out immediately; a burst is merged and
  // flushed once the watcher can settle.
  property var pendingTarget: null
  property double lastFlushMs: 0
  readonly property int writePaceMs: 300

  function commit(patch) {
    if (!shell || typeof shell.updateEntryInline !== "function") return false
    var base = root.live
    var merged = ({})
    for (var key in base) merged[key] = base[key]
    for (var change in patch) merged[change] = patch[change]
    root.shadow = Settings.normalize(merged)
    root.refreshLive()
    root.pendingTarget = root.shadow
    root.scheduleFlush()
    return true
  }

  function scheduleFlush() {
    var wait = Math.max(0, root.writePaceMs - (Date.now() - root.lastFlushMs))
    if (flushTimer.running && flushTimer.interval <= wait) return
    flushTimer.interval = wait
    flushTimer.restart()
  }

  function flushWrite() {
    if (root.pendingTarget === null) return
    if (!shell || typeof shell.updateEntryInline !== "function") return
    var next = root.pendingTarget
    root.pendingTarget = null
    root.lastFlushMs = Date.now()
    shell.updateEntryInline(pluginId, next)
  }

  // Once nothing is pending, adopt the host's settled snapshot. The popup writes
  // to the same entry through the host, so folding its result back into `shadow`
  // keeps a later drag from merging over a stale base and reverting a toggle.
  onConfigChanged: {
    if (root.pendingTarget === null) root.shadow = root.config
    root.refreshLive()
  }

  Timer {
    id: flushTimer
    onTriggered: root.flushWrite()
  }

  function setProfile(profile) {
    return powerService.setProfile(profile)
  }

  SystemService {
    id: systemService
    active: root.sampling
    intervalMs: root.effectiveIntervalMs
  }

  PowerService {
    id: powerService
  }

  GpuService {
    id: gpuService
    active: root.live.widgets.indexOf("gpu") !== -1 || root.panelViewing
    intervalMs: root.effectiveIntervalMs
  }

  DesktopSurface {
    config: root.live
    system: systemService
    power: powerService
    gpu: gpuService
    show: root.live.widgets.length > 0

    onResizeCommit: function (id, w, h) {
      var sizes = ({})
      for (var k in root.live.sizes) sizes[k] = root.live.sizes[k]
      sizes[id] = { w: w, h: h }
      root.commit({ sizes: sizes })
      root.resizeCommitted(id, w, h)
    }

    onMoveCommit: function (id, x, y) {
      var positions = ({})
      for (var k in root.live.positions) positions[k] = root.live.positions[k]
      positions[id] = { x: x, y: y }
      root.commit({ positions: positions })
      root.positionCommitted(id, x, y)
    }

    onProfileRequested: function (profile) {
      root.setProfile(profile)
    }
  }
}
