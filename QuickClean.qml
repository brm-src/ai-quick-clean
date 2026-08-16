import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  readonly property string pluginId: "io.github.brm-src.aismell-quick-clean"
  readonly property string helperPath: Qt.resolvedUrl("quick_clean.py").toString().replace("file://", "")
  property bool opened: false
  property bool busy: false
  property string cleanedText: ""
  property string uiLanguage: Qt.locale().name.toLowerCase().startsWith("es") ? "es" : "en"
  property string status: uiLanguage === "es"
    ? "Copia un mensaje, correo o párrafo y lo dejo más limpio."
    : "Copy a message, email, or paragraph and I will clean it up."
  property int changes: 0
  property var callback: null

  function words(es, en) { return root.uiLanguage === "es" ? es : en }

  function open() {
    root.opened = true
    root.cleanedText = ""
    root.changes = 0
    root.cleanClipboard()
  }

  function close() {
    root.opened = false
    root.busy = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function runHelper(command, done) {
    if (root.busy) return
    root.busy = true
    root.callback = done
    helper.command = ["python3", root.helperPath, command]
    helper.running = true
  }

  function handlePayload(raw) {
    root.busy = false
    var payload
    try {
      payload = JSON.parse(String(raw || "{}"))
    } catch (error) {
      root.status = root.words("aismell no pudo leer la respuesta.", "aismell could not read the response.")
      return
    }
    if (root.callback) root.callback(payload)
    root.callback = null
  }

  function cleanClipboard() {
    root.status = root.words("Leyendo y limpiando el portapapeles…", "Reading and cleaning the clipboard…")
    root.runHelper("clean-clipboard", function(payload) {
      if (!payload.ok) {
        root.cleanedText = ""
        root.changes = 0
        root.status = payload.error || root.words("No pude limpiar ese texto.", "I could not clean that text.")
        return
      }
      root.uiLanguage = payload.language === "es" ? "es" : "en"
      root.cleanedText = String(payload.text || "")
      root.changes = Number(payload.changes || 0)
      root.status = payload.message || root.words("Texto listo.", "Text ready.")
    })
  }

  function copyClean() {
    root.runHelper("copy-latest", function(payload) {
      root.status = payload.ok
        ? root.words("Texto limpio copiado.", "Clean text copied.")
        : (payload.error || root.words("No pude copiar el texto limpio.", "I could not copy the clean text."))
    })
  }

  IpcHandler {
    target: root.pluginId
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function show(): string { root.open(); return "ok" }
    function hide(): string { root.close(); return "ok" }
    function toggle(): string { root.toggle(); return "ok" }
  }

  Process {
    id: helper
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handlePayload(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.busy) {
        root.busy = false
        root.status = "aismell no pudo acceder al portapapeles."
      }
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData
      visible: root.opened
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: root.pluginId
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

      Keys.onEscapePressed: root.close()
      Keys.onReturnPressed: if (event.modifiers & Qt.ControlModifier) root.copyClean()

      Rectangle {
        anchors.fill: parent
        color: Util.alpha(Color.background, 0.72)
        MouseArea {
          anchors.fill: parent
          onClicked: root.close()
        }
      }

      Rectangle {
        id: card
        width: Math.min(600, parent.width - 36)
        height: Math.min(520, parent.height - 48)
        anchors.centerIn: parent
        radius: 18
        color: Util.alpha(Color.background, 0.98)
        border.width: 1
        border.color: Util.alpha(Color.accent, 0.72)

        MouseArea { anchors.fill: parent }

        Column {
          anchors.fill: parent
          anchors.margins: 22
          spacing: 14

          Row {
            width: parent.width
            Text {
              width: parent.width - closeButton.width - 12
              text: "aismell quick clean"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: 21
              font.bold: true
            }
            Rectangle {
              id: closeButton
              width: 30
              height: 30
              radius: 15
              color: closeMouse.containsMouse ? Util.alpha(Color.foreground, 0.12) : "transparent"
              Text {
                anchors.centerIn: parent
                text: "×"
                color: Color.foreground
                font.pixelSize: 24
              }
              MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.close()
              }
            }
          }

          Text {
            width: parent.width
            text: root.status
            color: root.cleanedText ? Util.alpha(Color.foreground, 0.72) : Color.foreground
            font.family: Style.font.family
            font.pixelSize: 14
            wrapMode: Text.Wrap
          }

          Rectangle {
            width: parent.width
            height: 1
            color: Util.alpha(Color.foreground, 0.12)
          }

          Rectangle {
            width: parent.width
            height: Math.max(160, parent.height - 185)
            radius: 12
            color: Util.alpha(Color.foreground, 0.055)
            border.width: 1
            border.color: Util.alpha(Color.foreground, 0.10)

            Flickable {
              anchors.fill: parent
              anchors.margins: 15
              contentWidth: width
              contentHeight: cleanText.implicitHeight
              clip: true

              Text {
                id: cleanText
                width: parent.width
                text: root.busy ? root.words("limpiando…", "cleaning…") : (root.cleanedText || root.words("Copia texto y vuelve a abrir esta ventana.", "Copy text and reopen this window."))
                color: root.cleanedText ? Color.foreground : Util.alpha(Color.foreground, 0.55)
                font.family: Style.font.family
                font.pixelSize: 15
                lineHeight: 1.3
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
              }
            }
          }

          Row {
            width: parent.width
            spacing: 10

            Rectangle {
              width: 150
              height: 40
              radius: 10
              color: reloadMouse.containsMouse ? Util.alpha(Color.foreground, 0.12) : Util.alpha(Color.foreground, 0.07)
              Text {
                anchors.centerIn: parent
                text: root.words("volver a limpiar", "clean again")
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: 13
              }
              MouseArea {
                id: reloadMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cleanClipboard()
              }
            }

            Item { width: parent.width - 150 - copyButton.width - 10; height: 1 }

            Rectangle {
              id: copyButton
              width: 136
              height: 40
              radius: 10
              color: root.cleanedText && !root.busy ? Color.accent : Util.alpha(Color.foreground, 0.10)
              Text {
                anchors.centerIn: parent
                text: root.words("copiar limpio", "copy clean")
                color: root.cleanedText && !root.busy ? Color.background : Util.alpha(Color.foreground, 0.42)
                font.family: Style.font.family
                font.pixelSize: 13
                font.bold: true
              }
              MouseArea {
                anchors.fill: parent
                enabled: root.cleanedText !== "" && !root.busy
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.copyClean()
              }
            }
          }
        }
      }
    }
  }
}
