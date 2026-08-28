import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Talks to the discord-ptt systemd --user service: reads its live state via
// the JSON file the daemon writes on every press/release/heartbeat (event
// driven, via FileView — no polling for the common case), and controls it
// via `systemctl --user`. The one thing the state file can't self-report is
// a `kill -9`/OOM that never reaches the daemon's cleanup handler, which is
// why `systemctl --user is-active` is also polled at a low, steady cadence
// as a crash-detection fallback.
Item {
  id: root

  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/discord-ptt/state.json"
  readonly property string unitName: "discord-ptt.service"
  readonly property int staleAfterSec: 8

  property var state: Model.parseState("")
  property bool systemctlActive: false
  property string status: "down"
  readonly property bool busy: controlProcess.running

  readonly property string keyName: Model.evdevKeyName(state.keycode)
  readonly property string glyph: Model.glyphFor(status)
  readonly property string statusLabel: Model.statusLabel(status)
  readonly property bool serviceEnabled: status !== "down"

  function _recompute() {
    status = Model.deriveStatus(state, systemctlActive, Date.now() / 1000, staleAfterSec)
  }

  function refreshActive() {
    if (!activeProcess.running) activeProcess.running = true
  }

  function setEnabled(on) {
    if (controlProcess.running) return
    controlProcess.command = ["systemctl", "--user", on ? "enable" : "disable", "--now", unitName]
    controlProcess.running = true
  }

  function toggle() {
    setEnabled(status === "down")
  }

  function restart() {
    if (controlProcess.running) return
    controlProcess.command = ["systemctl", "--user", "restart", unitName]
    controlProcess.running = true
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.state = Model.parseState(text())
      root._recompute()
    }
    onLoadFailed: {
      root.state = Model.parseState("")
      root._recompute()
    }
  }

  Process {
    id: activeProcess
    running: false
    command: ["systemctl", "--user", "is-active", root.unitName]
    stdout: StdioCollector {
      id: activeStdout
      waitForEnd: true
      onStreamFinished: {
        root.systemctlActive = String(text).trim() === "active"
        root._recompute()
      }
    }
  }

  Process {
    id: controlProcess
    running: false
    command: []
    onExited: function(exitCode) {
      settleTimer.restart()
    }
  }

  Timer {
    // Steady-state crash-detection cadence — the state file's own heartbeat
    // (~5s) plus this poll is what lets "down" show up even if the daemon
    // was killed with -9 and never got to write its own "service: down".
    id: pollTimer
    interval: 10000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refreshActive()
  }

  Timer {
    // Keeps `status` re-evaluating even when no file/process event fires,
    // so the "stale" (hung daemon) case is caught by wall-clock alone.
    id: ticker
    interval: 1000
    repeat: true
    running: true
    onTriggered: root._recompute()
  }

  Timer {
    // Right after enable/disable/restart, re-poll sooner than the 10s
    // steady-state cadence so the toggle/restart feels immediate.
    id: settleTimer
    interval: 700
    repeat: false
    onTriggered: root.refreshActive()
  }
}
