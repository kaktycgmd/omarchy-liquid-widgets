import QtQuick
import Quickshell.Io
import "../model/Sysfs.js" as Sysfs

// CPU and memory sampling.
//
// One timer drives three FileView reloads, and each file reports its own content
// back through onLoaded, so nothing blocks the GUI thread. `active` is the whole
// performance story: when no widget is on screen the timer stops and this object
// costs nothing.
Item {
  id: root

  property bool active: false
  property int intervalMs: 2000

  readonly property real cpuLoad: cpuSample.overall
  readonly property var coreLoads: cpuSample.cores
  readonly property int coreCount: coreLoads.length
  readonly property var memory: memorySample
  readonly property var load: loadSample

  property var cpuSample: ({ overall: Sysfs.UNKNOWN, cores: [] })
  property var memorySample: Sysfs.parseMeminfo("")
  property var loadSample: ({ one: Sysfs.UNKNOWN, five: Sysfs.UNKNOWN, fifteen: Sysfs.UNKNOWN })

  // The previous cumulative counters. /proc/stat is monotonic, so a single
  // sample says nothing on its own; load only exists once there are two.
  property var previousStat: null

  function sample() {
    statFile.reload()
    memoryFile.reload()
    loadFile.reload()
  }

  function applyStat(raw) {
    var next = Sysfs.parseCpuStat(raw)
    if (!next.overall) return
    if (previousStat) cpuSample = Sysfs.cpuLoad(previousStat, next)
    previousStat = next
  }

  // A stopped timer leaves counters behind that are minutes or hours old.
  // Diffing against them on resume would show one enormous spike, so the
  // baseline is dropped and the first tick after a resume only re-seeds it.
  function resetBaseline() {
    previousStat = null
    cpuSample = ({ overall: Sysfs.UNKNOWN, cores: [] })
  }

  onActiveChanged: {
    if (active) {
      resetBaseline()
      sample()
    }
  }

  Timer {
    interval: Math.max(500, root.intervalMs)
    running: root.active
    repeat: true
    onTriggered: root.sample()
  }

  FileView {
    id: statFile
    path: "/proc/stat"
    printErrors: false
    onLoaded: root.applyStat(text())
  }

  FileView {
    id: memoryFile
    path: "/proc/meminfo"
    printErrors: false
    onLoaded: root.memorySample = Sysfs.parseMeminfo(text())
  }

  FileView {
    id: loadFile
    path: "/proc/loadavg"
    printErrors: false
    onLoaded: root.loadSample = Sysfs.parseLoadAvg(text())
  }
}
