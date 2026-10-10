import QtQuick
import Quickshell.Io

// GPU sampling.
//
// Two real backends, chosen once at startup by probing the machine:
//
//   * NVIDIA via nvidia-smi (utilization, VRAM, temperature, name).
//   * AMD/amdgpu via the kernel's own sysfs nodes, which need no privileges:
//     gpu_busy_percent, mem_info_vram_used/total, and an hwmon temperature.
//
// Intel and anything else report present=false and the card says so, rather
// than showing a number that never moves. `active` gates all sampling, so a
// machine with no GPU widget costs nothing.
Item {
  id: root

  property bool active: false
  property int intervalMs: 2000

  // "" = not probed yet, then "amd", "nvidia" or "none".
  property string vendor: ""
  property string name: ""
  readonly property bool present: vendor === "amd" || vendor === "nvidia"

  // Fraction 0..1, or -1 when unknown.
  property real utilization: -1
  // Bytes.
  property real vramUsed: 0
  property real vramTotal: 0
  // Degrees Celsius, or -1 when unknown.
  property real temperature: -1

  property string busyPath: ""
  property string vramUsedPath: ""
  property string vramTotalPath: ""
  property string tempPath: ""

  readonly property real vramFraction: vramTotal > 0
    ? Math.max(0, Math.min(1, vramUsed / vramTotal)) : -1

  function toNumber(raw, fallback) {
    var n = Number(String(raw || "").trim())
    return isFinite(n) ? n : fallback
  }

  function sample() {
    if (vendor === "amd") {
      if (busyPath !== "") busyFile.reload()
      if (vramUsedPath !== "") vramUsedFile.reload()
      if (vramTotalPath !== "") vramTotalFile.reload()
      if (tempPath !== "") tempFile.reload()
    } else if (vendor === "nvidia") {
      if (!nvidiaProcess.running) nvidiaProcess.running = true
    }
  }

  function applyDiscovery(text) {
    var lines = String(text || "").split("\n")
    var found = {}
    for (var i = 0; i < lines.length; i++) {
      var eq = lines[i].indexOf("=")
      if (eq <= 0) continue
      found[lines[i].substring(0, eq).trim()] = lines[i].substring(eq + 1).trim()
    }
    root.vendor = found.vendor || "none"
    root.name = found.name || ""
    root.busyPath = found.busy || ""
    root.vramUsedPath = found.vram_used || ""
    root.vramTotalPath = found.vram_total || ""
    root.tempPath = found.temp || ""
    if (root.active) root.sample()
  }

  function applyNvidia(text) {
    // "util, mem_used, mem_total, temp, name"
    var line = String(text || "").split("\n")[0]
    if (!line) return
    var f = line.split(",")
    for (var i = 0; i < f.length; i++) f[i] = f[i].trim()
    root.utilization = root.toNumber(f[0], -1) / 100
    root.vramUsed = root.toNumber(f[1], 0) * 1048576
    root.vramTotal = root.toNumber(f[2], 0) * 1048576
    root.temperature = root.toNumber(f[3], -1)
    if (f[4]) root.name = f[4]
  }

  onActiveChanged: if (active) sample()
  onVendorChanged: if (active && vendor !== "") sample()

  Timer {
    interval: Math.max(500, root.intervalMs)
    running: root.active && root.vendor !== ""
    repeat: true
    onTriggered: root.sample()
  }

  Process {
    id: discover
    running: true
    command: ["sh", "-c", root.discoveryScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyDiscovery(text)
    }
  }

  readonly property string discoveryScript: [
    "if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L 2>/dev/null | grep -q 'GPU '; then",
    "  echo vendor=nvidia",
    "  nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 | sed 's/^/name=/'",
    "  exit 0",
    "fi",
    "busy=$(ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)",
    "if [ -n \"$busy\" ]; then",
    "  dev=$(dirname \"$busy\")",
    "  echo vendor=amd",
    "  echo busy=$busy",
    "  [ -f \"$dev/mem_info_vram_used\" ] && echo vram_used=$dev/mem_info_vram_used",
    "  [ -f \"$dev/mem_info_vram_total\" ] && echo vram_total=$dev/mem_info_vram_total",
    "  temp=$(ls \"$dev\"/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)",
    "  [ -n \"$temp\" ] && echo temp=$temp",
    "  exit 0",
    "fi",
    "echo vendor=none"
  ].join("\n")

  Process {
    id: nvidiaProcess
    command: ["nvidia-smi",
      "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,name",
      "--format=csv,noheader,nounits"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyNvidia(text)
    }
  }

  FileView {
    id: busyFile
    path: root.busyPath
    printErrors: false
    onLoaded: root.utilization = Math.max(0, Math.min(1, root.toNumber(text(), 0) / 100))
  }

  FileView {
    id: vramUsedFile
    path: root.vramUsedPath
    printErrors: false
    onLoaded: root.vramUsed = root.toNumber(text(), 0)
  }

  FileView {
    id: vramTotalFile
    path: root.vramTotalPath
    printErrors: false
    onLoaded: root.vramTotal = root.toNumber(text(), 0)
  }

  FileView {
    id: tempFile
    path: root.tempPath
    printErrors: false
    onLoaded: root.temperature = root.toNumber(text(), 0) / 1000
  }
}
