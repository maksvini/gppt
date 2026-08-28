import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar icon + popup for the discord-ptt systemd --user service. Mirrors what
// the GNOME panel extension gave the user (mic mute/unmute glyph, enable/
// disable switch, current PTT key) but talks to Service.qml (state file +
// systemctl --user) instead of GSettings + Gio.Subprocess.
Panel {
  id: root
  // Fixed, independent of the plugin's manifest "id" (which is
  // "<username>.discord-ptt" per Omarchy convention and varies per machine) —
  // keeps this file copy-pasteable across installs with no templating needed.
  moduleName: "gppt.discord-ptt"
  ipcTarget: "gppt.discord-ptt"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color barIconColor: ptt.status === "down" ? Qt.darker(barForeground, 1.55) : barForeground

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) ptt.refreshActive()

  Service {
    id: ptt
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function restart(): string { ptt.restart(); return "ok" }
    function enable(): string { ptt.setEnabled(true); return "ok" }
    function disable(): string { ptt.setEnabled(false); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ptt.glyph
    foreground: root.barIconColor
    tooltipText: ptt.statusLabel
    opacity: ptt.status === "down" ? 0.55 : 1.0

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) ptt.refreshActive()
      else if (buttonCode === Qt.MiddleButton) ptt.toggle()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") ptt.restart()
        else if (t === "e" || t === "E") { if (!ptt.busy) ptt.toggle() }
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Discord PTT"
          meta: ptt.statusLabel
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: ptt.status === "down" ? 0.5 : 1.0
          iconComponent: Component {
            Text {
              text: ptt.glyph
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        Text {
          width: parent.width
          text: ptt.state.keycode !== null
            ? ("Listening for: " + ptt.keyName + "  ·  evdev " + ptt.state.keycode)
            : "Listening for: —"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        PanelSeparator {
          foreground: root.foreground
        }

        Toggle {
          width: parent.width
          label: "Enable Push-to-Talk"
          description: ptt.busy ? "Applying…" : (ptt.serviceEnabled ? "Autostarts at login" : "Currently off")
          checked: ptt.serviceEnabled
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (!ptt.busy) ptt.toggle()
        }

        Button {
          text: "Restart service"
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          enabled: ptt.serviceEnabled && !ptt.busy
          onClicked: ptt.restart()
        }

        Text {
          width: parent.width
          text: "To change the PTT key, edit ~/.config/discord-ptt/env and restart."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
