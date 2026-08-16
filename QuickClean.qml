import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  readonly property string pluginId: "io.github.brm-src.aismell-quick-clean"
  readonly property bool isSpanish: uiLanguage === "es"
  readonly property int cardWidth: Math.min(Style.space(760), panel.width - Style.gapsOut * 2)
  property bool opened: false
  property bool busy: false
  property bool hasResult: false
  property string uiLanguage: Qt.locale().name.toLowerCase().startsWith("es") ? "es" : "en"
  property string sourceText: ""
  property string cleanedText: ""
  property string status: words("Copia algo y presiona limpiar.", "Copy something, then clean it.")
  property int changes: 0
  property var callback: null

  function words(es, en) { return root.isSpanish ? es : en }

  function open() {
    root.opened = true
    root.hasResult = false
    root.sourceText = ""
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

  readonly property string helperPath: Qt.resolvedUrl("quick_clean.py").toString().replace("file://", "")

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
    root.status = root.words("Leyendo el portapapeles…", "Reading the clipboard…")
    root.runHelper("clean-clipboard", function(payload) {
      if (!payload.ok) {
        root.hasResult = false
        root.sourceText = ""
        root.cleanedText = ""
        root.changes = 0
        root.status = payload.error || root.words("No pude limpiar ese texto.", "I could not clean that text.")
        return
      }
      root.uiLanguage = payload.language === "es" ? "es" : "en"
      root.sourceText = String(payload.source || "")
      root.cleanedText = String(payload.text || "")
      root.changes = Number(payload.changes || 0)
      root.hasResult = true
      root.status = payload.message || root.words("Resultado listo.", "Result ready.")
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
    function state(): string { return root.opened ? "open" : "closed" }
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
        root.status = root.words("aismell no pudo acceder al portapapeles.", "aismell could not access the clipboard.")
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
      Keys.onReturnPressed: if (event.modifiers & Qt.ControlModifier && root.changes > 0) root.copyClean()

      Rectangle {
        anchors.fill: parent
        color: Color.menu.scrim
        MouseArea {
          anchors.fill: parent
          onClicked: root.close()
        }
      }

      BorderSurface {
        id: card
        width: root.cardWidth
        height: Math.min(Style.space(510), parent.height - Style.gapsOut * 2)
        anchors.centerIn: parent
        radius: Style.cornerRadius
        color: Color.menu.background
        borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
        padding: Style.spacing.panelPadding

        MouseArea { anchors.fill: parent }

        Column {
          anchors.fill: parent
          anchors.topMargin: card.contentTopInset
          anchors.rightMargin: card.contentRightInset
          anchors.bottomMargin: card.contentBottomInset
          anchors.leftMargin: card.contentLeftInset
          spacing: Style.spacing.md

          Row {
            width: parent.width
            height: title.implicitHeight

            Column {
              width: parent.width - closeButton.width - Style.spacing.md
              spacing: Style.spacing.xs
              Text {
                id: title
                text: "aismell quick clean"
                color: Color.menu.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Text {
                width: parent.width
                text: root.words("Mira el cambio antes de reemplazar el portapapeles.", "Review the change before replacing your clipboard.")
                color: Color.menu.text
                opacity: 0.62
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
              }
            }
            Button {
              id: closeButton
              anchors.verticalCenter: parent.verticalCenter
              text: "×"
              fontSize: Style.font.iconLarge
              tooltipText: root.words("Cerrar", "Close")
              onClicked: root.close()
            }
          }

          Text {
            width: parent.width
            text: root.busy ? root.words("Limpiando…", "Cleaning…") : root.status
            color: root.changes > 0 ? Color.menu.text : Color.menu.text
            opacity: root.changes > 0 ? 0.82 : 0.62
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }

          Row {
            width: parent.width
            height: parent.height - y - actions.height
            spacing: Style.spacing.md

            BorderSurface {
              width: (parent.width - parent.spacing) / 2
              height: parent.height
              radius: Style.cornerRadius
              color: Style.controlFill(false, false, Color.menu.text, Color.accent)
              borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)
              padding: Style.spacing.controlPaddingX

              Column {
                anchors.fill: parent
                anchors.topMargin: parent.contentTopInset
                anchors.rightMargin: parent.contentRightInset
                anchors.bottomMargin: parent.contentBottomInset
                anchors.leftMargin: parent.contentLeftInset
                spacing: Style.spacing.sm
                Text {
                  text: root.words("original", "original")
                  color: Color.menu.text
                  opacity: 0.56
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                TextEdit {
                  width: parent.width
                  height: parent.height - y
                  text: root.hasResult ? root.sourceText : root.words("El texto del portapapeles aparecerá aquí.", "Your clipboard text will appear here.")
                  color: root.hasResult ? Color.menu.text : Color.menu.text
                  opacity: root.hasResult ? 0.76 : 0.48
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.body
                  wrapMode: TextEdit.Wrap
                  readOnly: true
                  selectByMouse: true
                  textFormat: TextEdit.PlainText
                  clip: true
                }
              }
            }

            BorderSurface {
              width: (parent.width - parent.spacing) / 2
              height: parent.height
              radius: Style.cornerRadius
              color: root.changes > 0 ? Style.selectedFillFor(Color.menu.text, Color.accent) : Style.controlFill(false, false, Color.menu.text, Color.accent)
              borderSpec: root.changes > 0 ? Border.controlSpec("selected", Color.menu.text, Color.accent) : Border.controlSpec("normal", Color.menu.text, Color.accent)
              padding: Style.spacing.controlPaddingX

              Column {
                anchors.fill: parent
                anchors.topMargin: parent.contentTopInset
                anchors.rightMargin: parent.contentRightInset
                anchors.bottomMargin: parent.contentBottomInset
                anchors.leftMargin: parent.contentLeftInset
                spacing: Style.spacing.sm
                Text {
                  text: root.words("versión limpia", "clean version")
                  color: root.changes > 0 ? Style.selectedStateColor(Color.menu.text, Color.accent) : Color.menu.text
                  opacity: root.changes > 0 ? 1 : 0.56
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                TextEdit {
                  width: parent.width
                  height: parent.height - y
                  text: root.hasResult ? root.cleanedText : root.words("Nada que revisar todavía.", "Nothing to review yet.")
                  color: root.changes > 0 ? Style.selectedStateColor(Color.menu.text, Color.accent) : Color.menu.text
                  opacity: root.hasResult ? 1 : 0.48
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.body
                  wrapMode: TextEdit.Wrap
                  readOnly: true
                  selectByMouse: true
                  textFormat: TextEdit.PlainText
                  clip: true
                }
              }
            }
          }

          Row {
            id: actions
            width: parent.width
            spacing: Style.spacing.sm

            Button {
              text: root.words("limpiar otro texto", "clean new clipboard")
              tooltipText: root.words("Lee de nuevo el portapapeles.", "Read the clipboard again.")
              bordered: true
              onClicked: root.cleanClipboard()
            }
            Item { width: parent.width - primaryAction.width - parent.spacing; height: 1 }
            Button {
              id: primaryAction
              visible: root.changes > 0
              selected: true
              text: root.words("reemplazar portapapeles", "replace clipboard")
              tooltipText: root.words("Copia la versión limpia.", "Copy the clean version.")
              onClicked: root.copyClean()
            }
          }
        }
      }
    }
  }
}
