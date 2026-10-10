import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "../model/Power.js" as Power

// Battery state and the power profile.
//
// Battery comes from UPower, which is signal-driven, so there is no polling on
// that path. The profile is read over D-Bus with busctl (about 6ms) rather than
// powerprofilesctl (about 250ms, it is Python), and only when something could
// have changed it: startup, an AC transition, or our own write.
//
// Writing goes through Omarchy's own omarchy-powerprofiles-set, so the choice is
// remembered per power source exactly as the stock power panel remembers it.
Item {
  id: root

  readonly property var device: UPower.displayDevice
  readonly property bool onBattery: UPower.onBattery
  readonly property bool present: !!device && device.isPresent

  readonly property real fraction: present ? Math.max(0, Math.min(1, device.percentage)) : Power.UNKNOWN
  readonly property bool charging: present && device.state === UPowerDeviceState.Charging
  readonly property bool fullyCharged: present && device.state === UPowerDeviceState.FullyCharged
  readonly property real secondsRemaining: {
    if (!present) return 0
    return charging ? Number(device.timeToFull || 0) : Number(device.timeToEmpty || 0)
  }
  readonly property bool low: Power.isLow(fraction, charging || fullyCharged)
  readonly property string icon: Power.batteryIcon(fraction, charging)

  property var profiles: []
  property string activeProfile: ""
  property string lastError: ""
  readonly property bool profilesAvailable: profiles.length > 0
  readonly property bool busy: setProcess.running

  function refreshProfiles() {
    if (!listProcess.running) listProcess.running = true
  }

  function refreshActiveProfile() {
    if (!activeProcess.running) activeProcess.running = true
  }

  function refresh() {
    refreshProfiles()
    refreshActiveProfile()
  }

  function profileLabel(name) {
    return Power.profileLabel(name)
  }

  // The only write in the plugin. An unrecognised name, or one this machine does
  // not offer, yields "" and nothing is run.
  function setProfile(name) {
    var safe = Power.sanitizeProfile(name, profiles)
    if (safe === "" || setProcess.running) return false
    lastError = ""
    setProcess.command = ["omarchy-powerprofiles-set", onBattery ? "battery" : "ac", safe]
    setProcess.running = true
    return true
  }

  function applyProfileList(raw) {
    var parsed = Power.parseProfileList(raw)
    profiles = parsed.profiles
    if (parsed.active !== "") activeProfile = parsed.active
  }

  Process {
    id: listProcess
    command: ["omarchy-powerprofiles-list", "--active-state"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyProfileList(text) }
  }

  Process {
    id: activeProcess
    command: ["busctl", "get-property", "net.hadess.PowerProfiles",
      "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var name = Power.parseActiveProfile(text)
        if (name !== "") root.activeProfile = name
      }
    }
  }

  Process {
    id: setProcess
    stderr: StdioCollector { id: setError; waitForEnd: true }
    onExited: function (exitCode) {
      if (exitCode !== 0)
        root.lastError = String(setError.text || "Could not change the power profile").slice(0, 160)
      // Re-read either way: a refused write leaves the old profile in place.
      root.refreshActiveProfile()
    }
  }

  Connections {
    target: UPower
    // Omarchy restores a remembered profile per power source on every AC
    // transition, so the displayed profile has to be re-read when that happens.
    function onOnBatteryChanged() { root.refreshActiveProfile() }
  }

  Component.onCompleted: refresh()
}
