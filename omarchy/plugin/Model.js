// Pure JS — no Qt/QML dependency, so it can be tested standalone under node.

// Raw kernel (evdev) keycodes, ported from the GNOME extension's prefs.js.
// NOT the GDK/XKB keycodes (those are evdev + 8).
const EVDEV_KEY_NAMES = {
  1:   'ESC',          2:   '1',            3:   '2',            4:   '3',
  5:   '4',            6:   '5',            7:   '6',            8:   '7',
  9:   '8',            10:  '9',            11:  '0',            14:  'Backspace',
  15:  'Tab',          28:  'Enter',        29:  'Left Ctrl',    42:  'Left Shift',
  54:  'Right Shift',  56:  'Left Alt',     57:  'Space',        58:  'Caps Lock',
  59:  'F1',           60:  'F2',           61:  'F3',           62:  'F4',
  63:  'F5',           64:  'F6',           65:  'F7',           66:  'F8',
  67:  'F9',           68:  'F10',          87:  'F11',          88:  'F12',
  97:  'Right Ctrl',   100: 'Right Alt',    111: 'Delete',       119: 'Pause',
  125: 'Left Meta',    126: 'Right Meta',   127: 'Menu',
  183: 'F13',          184: 'F14',          185: 'F15',          186: 'F16',
  272: 'Left Click',   273: 'Right Click',  274: 'Middle Click',
  275: 'Side Button',  276: 'Extra Button',
}

function evdevKeyName(code) {
  if (code === null || code === undefined || code === "") return "unknown"
  return EVDEV_KEY_NAMES[code] || ("Key " + code)
}

// Parses discord_ptt.py's --state-file JSON. Anything missing/unparseable
// reads as "service down" rather than throwing, since the file may not
// exist yet (daemon never started) or may be mid-write.
function parseState(text) {
  var fallback = {
    ok: false, service: "down", holding: false, muted: true,
    keycode: null, soundEnabled: true, ts: 0,
  }
  if (!text) return fallback
  var raw
  try {
    raw = JSON.parse(text)
  } catch (e) {
    return fallback
  }
  if (!raw || typeof raw !== "object") return fallback
  return {
    ok: true,
    service: raw.service === "up" ? "up" : "down",
    holding: raw.holding === true,
    muted: raw.muted !== false,
    keycode: (typeof raw.keycode === "number") ? raw.keycode : null,
    soundEnabled: raw.sound_enabled !== false,
    ts: (typeof raw.ts === "number") ? raw.ts : 0,
  }
}

// Three-plus-one derived states: down / idle / holding, with an extra
// "stale" case (service claims active but the daemon hasn't written in a
// while — a crash systemd hasn't noticed, or hung between heartbeats).
function deriveStatus(state, systemctlActive, nowSeconds, staleAfterSec) {
  if (!systemctlActive) return "down"
  if (!state.ok) return "starting"
  if (nowSeconds - state.ts > staleAfterSec) return "stale"
  return state.holding ? "holding" : "idle"
}

// Same two glyphs (mdi microphone / microphone-off) the built-in
// omarchy.audio widget uses for its input-mute icon, for visual consistency.
function glyphFor(status) {
  if (status === "holding") return "\u{f036c}" // microphone
  return "\u{f036d}" // microphone-off (down / idle / stale / starting)
}

function statusLabel(status) {
  switch (status) {
    case "holding":  return "Running — live"
    case "idle":     return "Running — muted"
    case "starting": return "Starting…"
    case "stale":    return "Not responding"
    default:         return "Not running"
  }
}
