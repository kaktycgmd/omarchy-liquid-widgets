// Battery presentation and the power-profile allowlist.
//
// Setting a profile is the only system state this plugin changes, so the value
// that reaches a command line is gated twice: it must be one of the three names
// power-profiles-daemon defines, AND it must appear in the list the running
// daemon reported for this machine.
var UNKNOWN = -1

var SAVER = "power-saver"
var BALANCED = "balanced"
var PERFORMANCE = "performance"

var KNOWN_PROFILES = [SAVER, BALANCED, PERFORMANCE]

var LABELS = {}
LABELS[SAVER] = "Saver"
LABELS[BALANCED] = "Balanced"
LABELS[PERFORMANCE] = "Performance"

var ICONS = {}
ICONS[SAVER] = "\uF32A"
ICONS[BALANCED] = "\uF08A"
ICONS[PERFORMANCE] = "\uF4C5"

function isKnownProfile(value) {
  return KNOWN_PROFILES.indexOf(String(value || "")) !== -1
}

function sanitizeProfile(value, available) {
  var name = String(value || "").trim()
  if (!isKnownProfile(name)) return ""
  var list = Array.isArray(available) ? available : []
  if (list.length === 0) return ""
  return list.indexOf(name) !== -1 ? name : ""
}

// `omarchy-powerprofiles-list --active-state` prints "<name>\t<0|1>" per line.
function parseProfileList(raw) {
  var lines = String(raw || "").split("\n")
  var profiles = []
  var active = ""
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "") continue
    var fields = line.split("\t")
    var name = String(fields[0] || "").trim()
    if (!isKnownProfile(name) || profiles.indexOf(name) !== -1) continue
    profiles.push(name)
    if (String(fields[1] || "").trim() === "1") active = name
  }
  profiles.sort(function (a, b) {
    return KNOWN_PROFILES.indexOf(a) - KNOWN_PROFILES.indexOf(b)
  })
  return { profiles: profiles, active: active }
}

// `busctl get-property ... ActiveProfile` replies with: s "balanced"
function parseActiveProfile(raw) {
  var match = String(raw || "").match(/"([^"]*)"/)
  var name = match ? match[1] : ""
  return isKnownProfile(name) ? name : ""
}

function profileLabel(name) { return LABELS[name] || String(name || "") }
function profileIcon(name) { return ICONS[name] || ICONS[BALANCED] }

var DISCHARGING_ICONS = ["\uF242", "\uF243", "\uF244", "\uF245", "\uF246",
  "\uF247", "\uF248", "\uF249", "\uF24A", "\uF240"]
var CHARGING_ICONS = ["\uF089", "\uF07A", "\uF07B", "\uF07C", "\uF07D",
  "\uF07E", "\uF07F", "\uF080", "\uF081", "\uF082"]

function batteryIcon(fraction, charging) {
  var value = typeof fraction === "number" && isFinite(fraction) ? fraction : 0
  var index = Math.max(0, Math.min(9, Math.floor(Math.max(0, Math.min(1, value)) * 10)))
  return charging ? CHARGING_ICONS[index] : DISCHARGING_ICONS[index]
}

var LOW_FRACTION = 0.2

function isLow(fraction, charging) {
  if (charging) return false
  return typeof fraction === "number" && isFinite(fraction) && fraction <= LOW_FRACTION
}

if (typeof module !== "undefined") {
  module.exports = {
    UNKNOWN: UNKNOWN,
    SAVER: SAVER, BALANCED: BALANCED, PERFORMANCE: PERFORMANCE,
    KNOWN_PROFILES: KNOWN_PROFILES,
    LOW_FRACTION: LOW_FRACTION,
    isKnownProfile: isKnownProfile,
    sanitizeProfile: sanitizeProfile,
    parseProfileList: parseProfileList,
    parseActiveProfile: parseActiveProfile,
    profileLabel: profileLabel,
    profileIcon: profileIcon,
    batteryIcon: batteryIcon,
    isLow: isLow
  }
}
