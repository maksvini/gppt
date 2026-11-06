import QtQuick
import Quickshell
import Quickshell.Io

// Owns the PTT daemon. The bar builds one widget per monitor, so the daemon
// lives here, once, and the widgets only read and change this state.
Item {
  id: root

  property var shell: null

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/discord-ptt.json"

  // Settings, persisted to configPath. keyCode is a raw evdev code.
  property bool enabled: true
  property int keyCode: 56
  property string keyName: "KEY_LEFTALT"
  property bool sound: true

  property bool configLoaded: false
  property bool pendingStart: false
  // Why the daemon cannot work, in words the popup can show. Empty when fine.
  property string problem: ""

  readonly property bool running: daemon.running
  readonly property bool capturing: captureProc.running
  readonly property string keyLabel: prettyKey(keyName)

  // KEY_LEFTALT reads as "Left Alt", BTN_SIDE as "Mouse Side".
  function prettyKey(name) {
    var raw = String(name || "")
    var mouse = raw.indexOf("BTN_") === 0
    var words = raw.replace(/^(KEY|BTN)_/, "").replace(/^(LEFT|RIGHT)(?=[A-Z])/, "$1_").split("_")
    var label = words.filter(function(w) { return w !== "" }).map(function(w) {
      return w.charAt(0) + w.slice(1).toLowerCase()
    }).join(" ")
    return (mouse ? "Mouse " : "") + (label || raw)
  }

  function applyConfig(text) {
    var data = {}
    try {
      data = JSON.parse(text || "{}") || {}
    } catch (e) {
      console.warn("discord-ptt: ignoring unreadable config:", e)
    }

    if (typeof data.enabled === "boolean") root.enabled = data.enabled
    if (typeof data.keyCode === "number" && data.keyCode > 0) root.keyCode = data.keyCode
    if (typeof data.keyName === "string" && data.keyName) root.keyName = data.keyName
    if (typeof data.sound === "boolean") root.sound = data.sound

    root.configLoaded = true
    root.sync()
  }

  function save() {
    configFile.setText(JSON.stringify({
      enabled: root.enabled,
      keyCode: root.keyCode,
      keyName: root.keyName,
      sound: root.sound
    }, null, 2) + "\n")
    root.sync()
  }

  function setEnabled(value) {
    if (root.enabled === !!value) return
    root.enabled = !!value
    root.save()
  }

  function setSound(value) {
    if (root.sound === !!value) return
    root.sound = !!value
    root.save()
  }

  function setKey(code, name) {
    var next = Number(code)
    if (!(next > 0)) return false
    root.keyCode = next
    root.keyName = String(name || ("KEY_" + next))
    root.save()
    return true
  }

  function startCapture() {
    if (!captureProc.running) captureProc.running = true
  }

  function cancelCapture() {
    captureProc.running = false
  }

  // The daemon takes its settings as arguments, so every change restarts it.
  // Debounced, since a config save also arrives back as a file change.
  function sync() {
    if (root.configLoaded) restartTimer.restart()
  }

  function daemonCommand() {
    var command = [
      "python3", root.pluginDir + "/daemon/launch.py", root.pluginDir + "/daemon/discord_ptt.py",
      "--key", String(root.keyCode),
      "--sound-on", root.pluginDir + "/sounds/ptt_on.wav",
      "--sound-off", root.pluginDir + "/sounds/ptt_off.wav"
    ]
    if (!root.sound) command.push("--no-sound")
    return command
  }

  function start() {
    daemon.command = root.daemonCommand()
    daemon.running = true
    preflight.running = true
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyConfig(text())
    onLoadFailed: root.applyConfig("")
  }

  Timer {
    id: restartTimer
    interval: 300
    onTriggered: {
      if (daemon.running) {
        // SIGTERM, so the daemon unmutes Discord on its way out. A wanted
        // restart is picked up once it has actually gone.
        root.pendingStart = root.enabled
        daemon.running = false
      } else if (root.enabled) {
        root.start()
      }
    }
  }

  Process {
    id: daemon
    stderr: SplitParser {
      onRead: function(line) { console.log("[discord-ptt]", line) }
    }
    onExited: function(exitCode, exitStatus) {
      if (root.pendingStart) {
        root.pendingStart = false
        root.start()
      } else if (root.enabled) {
        // Died on its own. Retry slowly rather than spin on a missing module.
        preflight.running = true
        retryTimer.restart()
      }
    }
  }

  Timer {
    id: retryTimer
    interval: 15000
    onTriggered: if (root.enabled && !daemon.running && !restartTimer.running) root.start()
  }

  // The daemon keeps running with no readable devices, waiting for hotplug, so
  // a missing input group shows up as PTT silently doing nothing. Ask outright.
  Process {
    id: preflight
    command: ["sh", "-c", "python3 -c 'import evdev' 2>/dev/null || { echo no-evdev; exit 0; }; "
      + "for d in /dev/input/event*; do [ -r \"$d\" ] && { echo ok; exit 0; }; done; echo no-access"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var result = String(text || "").trim()
        if (result === "no-evdev") root.problem = "python-evdev is not installed"
        else if (result === "no-access") root.problem = "No access to /dev/input. Add yourself to the input group, then log out and in."
        else root.problem = ""
      }
    }
  }

  Process {
    id: captureProc
    command: ["python3", root.pluginDir + "/daemon/capture_key.py", "--timeout", "10"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var result
        try {
          result = JSON.parse(text || "{}")
        } catch (e) {
          return
        }
        if (result && result.code) root.setKey(result.code, result.name)
        else if (result && result.error) root.problem = result.error
      }
    }
  }

  IpcHandler {
    target: "discord-ptt"

    function status(): string {
      return JSON.stringify({
        enabled: root.enabled,
        running: root.running,
        keyCode: root.keyCode,
        keyName: root.keyName,
        sound: root.sound,
        problem: root.problem
      })
    }

    function toggle(): string {
      root.setEnabled(!root.enabled)
      return root.enabled ? "on" : "off"
    }

    function setKey(code: string, name: string): string {
      return root.setKey(code, name) ? "ok" : "invalid"
    }
  }
}
