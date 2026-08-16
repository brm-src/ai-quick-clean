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
  property string rewrittenText: ""
  property var changes: []
  property string status: words("Copia algo y presiona reescribir.", "Copy something, then rewrite it.")
  property var callback: null

  function words(es, en) { return root.isSpanish ? es : en }
  function errorText(payload) {
    switch (payload.errorCode) {
      case "empty": return root.words("Pega o escribe un texto antes de reescribirlo.", "Paste or type text before rewriting it.")
      case "too-long": return root.words("Este atajo admite hasta 3.000 caracteres.", "This shortcut accepts up to 3,000 characters.")
      case "rewrite-unavailable": return root.words("No pude conectar con el servicio de aismell. Intenta otra vez.", "I could not reach the aismell service. Try again.")
      case "nothing-to-copy": return root.words("No hay una versión reescrita para copiar.", "There is no rewritten version to copy.")
      case "clipboard-failed": return root.words("No pude acceder al portapapeles.", "I could not access the clipboard.")
      default: return root.words("No pude completar esa acción.", "I could not complete that action.")
    }
  }

  function open() {
    root.opened = true
    root.hasResult = false
    root.sourceText = ""
    root.rewrittenText = ""
    root.changes = []
    root.status = root.words("Pega o escribe un texto corto para reescribirlo.", "Paste or type a short text to rewrite.")
  }

  function close() {
    root.opened = false
    root.busy = false
    root.callback = null
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function runHelper(command, input, done) {
    if (root.busy) return
    root.busy = true
    root.callback = done
    helper.inputText = String(input || "")
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

  function rewriteClipboard() {
    root.status = root.words("aismell está reescribiendo el portapapeles…", "aismell is rewriting the clipboard…")
    root.runHelper("rewrite-clipboard", "", function(payload) {
      root.applyRewritePayload(payload)
    })
  }

  function rewriteText() {
    if (!root.sourceText.trim()) {
      root.status = root.words("Pega o escribe un texto antes de reescribirlo.", "Paste or type text before rewriting it.")
      return
    }
    root.status = root.words("aismell está preparando una versión más directa…", "aismell is preparing a more direct version…")
    root.runHelper("rewrite-stdin", root.sourceText, function(payload) {
      root.applyRewritePayload(payload)
    })
  }

  function applyRewritePayload(payload) {
    if (!payload.ok) {
      root.hasResult = false
      root.rewrittenText = ""
      root.changes = []
      root.status = root.errorText(payload)
      return
    }
    root.sourceText = String(payload.source || "")
    root.rewrittenText = String(payload.text || "")
    root.changes = payload.changes || []
    root.hasResult = true
    root.status = root.changes.length > 0
      ? root.words("Versión directa lista. Revísala antes de copiar.", "Direct version ready. Review it before copying.")
      : root.words("aismell no vio relleno claro; dejó tu texto igual.", "aismell found no clear filler and left your text unchanged.")
  }

  function copyRewrittenText() {
    root.runHelper("copy-stdin", root.rewrittenText, function(payload) {
      root.status = payload.ok
        ? root.words("Versión reescrita copiada.", "Rewritten version copied.")
        : root.errorText(payload)
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
    property string inputText: ""
    stdinEnabled: true
    onStarted: {
      write(inputText + "\u001e")
      inputText = ""
    }
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

  PanelWindow {
    id: panel
    screen: Quickshell.screens[0]
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: root.pluginId
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Keys.onEscapePressed: root.close()
    Keys.onReturnPressed: if (event.modifiers & Qt.ControlModifier) root.rewriteText()

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
            height: titleColumn.implicitHeight

            Column {
              id: titleColumn
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
                text: root.words("aismell propone una versión más directa; tú decides si usarla.", "aismell proposes a more direct version; you decide whether to use it.")
                color: Color.menu.text
                opacity: 0.62
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
              }
              Text {
                width: parent.width
                text: root.words("Envía el texto al servicio de aismell (Cloudflare). No se guarda.", "Sends text to aismell's Cloudflare service. It is not stored.")
                color: Color.menu.text
                opacity: 0.46
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
            text: root.busy ? root.words("Reescribiendo con aismell…", "Rewriting with aismell…") : root.status
            color: root.changes.length > 0 ? Color.menu.text : Color.menu.text
            opacity: root.changes.length > 0 ? 0.82 : 0.62
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }

          Text {
            visible: root.hasResult
            width: parent.width
            text: root.changes.length > 0
              ? root.words("Cambios propuestos: ", "Proposed changes: ") + root.changes.length
              : root.words("Sin relleno claro que cambiar.", "No clear filler to change.")
            color: Color.menu.text
            opacity: 0.58
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
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
                  text: root.words("tu texto", "your text")
                  color: Color.menu.text
                  opacity: 0.56
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                Flickable {
                  id: sourceScroll
                  width: parent.width
                  height: parent.height - y
                  contentWidth: width
                  contentHeight: Math.max(height, sourceEditor.height)
                  clip: true

                  TextEdit {
                    id: sourceEditor
                    width: sourceScroll.width
                    height: Math.max(sourceScroll.height, contentHeight)
                    text: root.sourceText
                    color: Color.menu.text
                    opacity: 0.9
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.body
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    textFormat: TextEdit.PlainText
                    onTextChanged: {
                      if (activeFocus && text !== root.sourceText) {
                        root.sourceText = text
                        root.hasResult = false
                        root.rewrittenText = ""
                        root.changes = []
                        root.status = root.words("Listo para reescribir con aismell.", "Ready to rewrite with aismell.")
                      }
                    }
                    Text {
                      visible: sourceEditor.text === "" && !sourceEditor.activeFocus
                      anchors.fill: parent
                      text: root.words("Pega o escribe un mensaje, correo o párrafo corto.", "Paste or type a short message, email, or paragraph.")
                      color: Color.menu.text
                      opacity: 0.45
                      font: sourceEditor.font
                      wrapMode: Text.Wrap
                    }
                  }
                }
              }
            }

            BorderSurface {
              width: (parent.width - parent.spacing) / 2
              height: parent.height
              radius: Style.cornerRadius
              color: root.changes.length > 0 ? Style.selectedFillFor(Color.menu.text, Color.accent) : Style.controlFill(false, false, Color.menu.text, Color.accent)
              borderSpec: root.changes.length > 0 ? Border.controlSpec("selected", Color.menu.text, Color.accent) : Border.controlSpec("normal", Color.menu.text, Color.accent)
              padding: Style.spacing.controlPaddingX

              Column {
                anchors.fill: parent
                anchors.topMargin: parent.contentTopInset
                anchors.rightMargin: parent.contentRightInset
                anchors.bottomMargin: parent.contentBottomInset
                anchors.leftMargin: parent.contentLeftInset
                spacing: Style.spacing.sm
                Text {
                  text: root.words("versión propuesta", "proposed version")
                  color: root.changes.length > 0 ? Style.selectedStateColor(Color.menu.text, Color.accent) : Color.menu.text
                  opacity: root.changes.length > 0 ? 1 : 0.56
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                Item {
                  width: parent.width
                  height: parent.height - y
                  Flickable {
                    anchors.fill: parent
                    visible: root.hasResult
                    contentWidth: width
                    contentHeight: Math.max(height, rewrittenTextItem.implicitHeight)
                    clip: true
                    Text {
                      id: rewrittenTextItem
                      width: parent.width
                      text: root.rewrittenText
                      color: Color.menu.text
                      opacity: 0.9
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.font.body
                      wrapMode: Text.Wrap
                    }
                  }
                  Text {
                    anchors.fill: parent
                    visible: !root.hasResult
                    text: root.words("Pide una reescritura para comparar una versión más directa.", "Request a rewrite to compare a more direct version.")
                    color: Color.menu.text
                    opacity: 0.48
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.body
                    wrapMode: Text.Wrap
                  }
                }
              }
            }
          }

          Row {
            id: actions
            width: parent.width
            spacing: Style.spacing.sm

            Button {
              id: clipboardAction
              text: root.words("reescribir portapapeles", "rewrite clipboard")
              tooltipText: root.words("Envía lo que acabas de copiar al servicio de aismell para una versión más directa.", "Send what you copied to aismell's service for a more direct version.")
              bordered: true
              active: !root.busy
              onClicked: root.rewriteClipboard()
            }
            Button {
              id: cleanAction
              text: root.words("reescribir texto", "rewrite text")
              active: root.sourceText !== "" && !root.busy
              tooltipText: root.words("Envía el texto de la izquierda al servicio de aismell para una versión más directa.", "Send the text on the left to aismell's service for a more direct version.")
              onClicked: root.rewriteText()
            }
            Item { width: parent.width - clipboardAction.width - cleanAction.width - primaryAction.width - parent.spacing * 2; height: 1 }
            Button {
              id: primaryAction
              visible: root.hasResult && root.rewrittenText !== ""
              active: !root.busy
              selected: true
              text: root.words("copiar versión", "copy version")
              tooltipText: root.words("Copia la versión propuesta al portapapeles.", "Copy the proposed version to the clipboard.")
              onClicked: root.copyRewrittenText()
            }
          }
        }
      }
    }
}
