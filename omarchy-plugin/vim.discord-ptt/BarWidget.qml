import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "vim.discord-ptt"

  // The service is looked up through a call, which a binding cannot watch, so
  // ask again until it has been mounted.
  property var service: null
  property bool popupOpen: false

  readonly property bool pttEnabled: service ? service.enabled : false
  readonly property bool capturing: service ? service.capturing : false
  readonly property string problem: service ? service.problem : ""
  readonly property string keyLabel: service ? service.keyLabel : ""

  function lookupService() {
    if (bar && bar.shell && typeof bar.shell.serviceFor === "function")
      root.service = bar.shell.serviceFor(root.moduleName)
  }

  function close() {
    popupOpen = false
  }

  onPopupOpenChanged: if (!popupOpen && service && service.capturing) service.cancelCapture()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Timer {
    interval: 500
    running: root.service === null
    repeat: true
    triggeredOnStart: true
    onTriggered: root.lookupService()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.pttEnabled ? "󰍬" : "󰍭"
    dimmed: !root.pttEnabled
    active: root.pttEnabled && root.problem !== ""
    tooltipText: root.problem !== "" ? "Push-to-talk: " + root.problem
      : (root.pttEnabled ? "Push-to-talk on · hold " + root.keyLabel : "Push-to-talk off")
    onPressed: function(b) {
      if (b === Qt.RightButton) root.popupOpen = !root.popupOpen
      else if (b === Qt.LeftButton && root.service) root.service.setEnabled(!root.pttEnabled)
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(300))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Text {
        textFormat: Text.PlainText
        text: "Discord Push-to-Talk"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Toggle {
        width: parent.width
        label: "Enable PTT"
        description: "Mute Discord until the key is held"
        checked: root.pttEnabled
        foreground: root.bar.foreground
        onClicked: if (root.service) root.service.setEnabled(!root.pttEnabled)
      }

      Toggle {
        width: parent.width
        label: "Click sound"
        description: "Play a click on press and release"
        checked: root.service ? root.service.sound : false
        foreground: root.bar.foreground
        onClicked: if (root.service) root.service.setSound(!root.service.sound)
      }

      PanelSeparator {
        foreground: root.bar.foreground
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: root.capturing ? "Press a key or mouse button…  (Esc cancels)" : "Key: " + root.keyLabel
        color: root.capturing ? root.bar.urgent : root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Button {
        text: root.capturing ? "Cancel" : "Change key"
        bordered: true
        foreground: root.bar.foreground
        onClicked: {
          if (!root.service) return
          if (root.capturing) root.service.cancelCapture()
          else root.service.startCapture()
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: root.problem !== ""
        width: parent.width
        text: root.problem
        color: root.bar.urgent
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }
}
