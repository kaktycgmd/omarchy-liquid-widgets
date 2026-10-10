// Settings normalisation for Liquid Widgets.
//
// The stored object comes from shell.json and is untrusted: any field may be
// missing, the wrong type, or a value someone typed by hand. Every field is
// coerced and clamped so a bad value yields a working widget rather than a
// broken binding, and anything unrecognised falls back to its default.
var WIDGET_CLOCK = "clock"
var WIDGET_SYSTEM = "system"
var WIDGET_GPU = "gpu"
var WIDGET_POWER = "power"
var WIDGET_BATTERY = "battery"

// Canonical order. A widget toggled off and back on returns to its place here.
var KNOWN_WIDGETS = [WIDGET_CLOCK, WIDGET_SYSTEM, WIDGET_GPU, WIDGET_POWER, WIDGET_BATTERY]

var POSITIONS = [
  "top-left", "top-center", "top-right",
  "middle-left", "middle-right",
  "bottom-left", "bottom-center", "bottom-right"
]

var CLOCK_STYLES = ["default", "digits"]

var DEFAULTS = {
  widgets: KNOWN_WIDGETS.slice(),
  // Absolute top-left screen coordinates per widget, once the user drags one.
  // Absent ids flow from `position` instead.
  positions: {},
  sizes: {},
  position: "top-right",
  marginX: 28,
  marginY: 20,
  cardWidth: 240,
  spacing: 12,
  opacity: 0.35,
  radius: 22,
  monitor: "",
  intervalMs: 2000,
  timeFormat: "24h",
  clockStyle: "default",
  showDate: true,
  showLabels: true,
  showCpuCores: true
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function clamp(value, min, max, fallback) {
  var n = Number(value)
  if (!isFinite(n)) return fallback
  return Math.max(min, Math.min(max, n))
}

// Array.isArray is false for a list that crossed the QML boundary as a
// sequence, so the length is what decides.
function asList(value) {
  if (Array.isArray(value)) return value
  if (!value || typeof value !== "object") return []
  var length = value.length
  if (typeof length !== "number" || !isFinite(length) || length < 0) return []
  var out = []
  for (var i = 0; i < Math.min(Math.floor(length), 64); i++) out.push(value[i])
  return out
}

function normalizeWidgets(value) {
  var wanted = asList(value)
  var seen = {}
  for (var i = 0; i < wanted.length; i++) {
    var id = String(wanted[i] || "")
    if (KNOWN_WIDGETS.indexOf(id) !== -1) seen[id] = true
  }
  var out = []
  for (var k = 0; k < KNOWN_WIDGETS.length; k++) {
    if (seen[KNOWN_WIDGETS[k]]) out.push(KNOWN_WIDGETS[k])
  }
  return out
}

function normalizeSizes(value) {
  if (!isPlainObject(value)) return {}
  var out = {}
  for (var i = 0; i < KNOWN_WIDGETS.length; i++) {
    var id = KNOWN_WIDGETS[i]
    var entry = value[id]
    if (!isPlainObject(entry)) continue
    var w = clamp(entry.w, 120, 2000, 0)
    var h = clamp(entry.h, 80, 2000, 0)
    if (w > 0 && h > 0) out[id] = { w: Math.round(w), h: Math.round(h) }
  }
  return out
}

// Absolute positions are clamped to a sane range but not to a screen: the
// screen is not known here, and a position that is off-screen on one monitor
// may be correct on another. The surface clamps to its own screen at draw time.
function normalizePositions(value) {
  if (!isPlainObject(value)) return {}
  var out = {}
  for (var i = 0; i < KNOWN_WIDGETS.length; i++) {
    var id = KNOWN_WIDGETS[i]
    var entry = value[id]
    if (!isPlainObject(entry)) continue
    var x = Number(entry.x)
    var y = Number(entry.y)
    if (!isFinite(x) || !isFinite(y)) continue
    out[id] = {
      x: Math.round(Math.max(-20000, Math.min(20000, x))),
      y: Math.round(Math.max(-20000, Math.min(20000, y)))
    }
  }
  return out
}

// The plugin id's own inline settings live inside the bar layout entry, so the
// service can read the live value from the host's bar-config snapshot.
function fromBarConfig(barConfig, id) {
  if (!isPlainObject(barConfig) || !isPlainObject(barConfig.layout)) return {}
  var sections = ["left", "center", "right"]
  for (var s = 0; s < sections.length; s++) {
    var arr = asList(barConfig.layout[sections[s]])
    for (var i = 0; i < arr.length; i++) {
      if (arr[i] && String(arr[i].id) === String(id)) return arr[i]
    }
  }
  return {}
}

function normalize(raw) {
  var value = isPlainObject(raw) ? raw : {}
  var radius = clamp(value.radius, 0, 64, DEFAULTS.radius)
  var out = {}
  out.widgets = normalizeWidgets(value.widgets !== undefined ? value.widgets : DEFAULTS.widgets)
  out.positions = normalizePositions(value.positions)
  out.sizes = normalizeSizes(value.sizes)
  out.position = POSITIONS.indexOf(String(value.position)) !== -1
    ? String(value.position) : DEFAULTS.position
  out.marginX = clamp(value.marginX, 0, 400, DEFAULTS.marginX)
  out.marginY = clamp(value.marginY, 0, 400, DEFAULTS.marginY)
  out.cardWidth = clamp(value.cardWidth, 120, 900, DEFAULTS.cardWidth)
  out.spacing = clamp(value.spacing, 0, 80, DEFAULTS.spacing)
  out.opacity = clamp(value.opacity, 0.05, 1, DEFAULTS.opacity)
  out.radius = radius
  out.monitor = typeof value.monitor === "string" ? value.monitor : DEFAULTS.monitor
  out.intervalMs = clamp(value.intervalMs, 500, 60000, DEFAULTS.intervalMs)
  out.timeFormat = String(value.timeFormat) === "12h" ? "12h" : "24h"
  out.clockStyle = CLOCK_STYLES.indexOf(String(value.clockStyle)) !== -1
    ? String(value.clockStyle) : DEFAULTS.clockStyle
  out.showDate = value.showDate === undefined ? DEFAULTS.showDate : !!value.showDate
  out.showLabels = value.showLabels === undefined ? DEFAULTS.showLabels : !!value.showLabels
  out.showCpuCores = value.showCpuCores === undefined ? DEFAULTS.showCpuCores : !!value.showCpuCores
  return out
}
