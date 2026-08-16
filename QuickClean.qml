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
  property var findings: []
  property string status: words("Copia algo y presiona revisar.", "Copy something, then review it.")
  property int score: 0
  property int changes: 0
  property var callback: null

  function words(es, en) { return root.isSpanish ? es : en }
  function errorText(payload) {
    switch (payload.errorCode) {
      case "empty": return root.words("Pega o escribe un texto antes de revisarlo.", "Paste or type text before reviewing it.")
      case "too-long": return root.words("Este atajo admite hasta 3.000 caracteres.", "This shortcut accepts up to 3,000 characters.")
      case "engine-missing": return root.words("No encontré el motor local de aismell.", "I could not find the local aismell engine.")
      case "nothing-to-copy": return root.words("No hay una propuesta para copiar.", "There is no proposal to copy.")
      case "clipboard-failed": return root.words("No pude acceder al portapapeles.", "I could not access the clipboard.")
      default: return root.words("No pude completar esa acción.", "I could not complete that action.")
    }
  }

  function open() {
    root.opened = true
    root.hasResult = false
    root.sourceText = ""
    root.findings = []
    root.score = 0
    root.changes = 0
    root.status = root.words("Pega o escribe un texto corto para revisarlo.", "Paste or type a short text to review.")
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

  function reviewClipboard() {
    root.status = root.words("aismell está revisando el portapapeles…", "aismell is reviewing the clipboard…")
    root.runHelper("analyze-clipboard", "", function(payload) {
      root.applyAnalysisPayload(payload)
    })
  }

  function reviewText() {
    if (!root.sourceText.trim()) {
      root.status = root.words("Pega o escribe un texto antes de revisarlo.", "Paste or type text before reviewing it.")
      return
    }
    root.status = root.words("aismell está buscando señales reales…", "aismell is looking for real signals…")
    root.runHelper("analyze-stdin", root.sourceText, function(payload) {
      root.applyAnalysisPayload(payload)
    })
  }

  function applyAnalysisPayload(payload) {
    if (!payload.ok) {
      root.hasResult = false
      root.findings = []
      root.score = 0
      root.changes = 0
      root.status = root.errorText(payload)
      return
    }
    root.uiLanguage = payload.language === "es" ? "es" : "en"
    root.sourceText = String(payload.source || "")
    root.findings = payload.findings || []
    root.score = Number(payload.score || 0)
    root.changes = root.findings.length
    root.hasResult = true
    root.status = payload.message || root.words("Revisión lista.", "Review ready.")
  }

  function copyEditedText() {
    root.runHelper("copy-stdin", root.sourceText, function(payload) {
      root.status = payload.ok
        ? root.words("Texto editado copiado.", "Edited text copied.")
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
    Keys.onReturnPressed: if (event.modifiers & Qt.ControlModifier) root.reviewText()

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
                text: root.words("aismell marca lo que merece atención; tú decides qué reescribir.", "aismell marks what deserves attention; you decide what to rewrite.")
                color: Color.menu.text
                opacity: 0.62
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
              }
              Text {
                width: parent.width
                text: root.words("Procesado localmente; no se envía ni se guarda en disco.", "Processed locally; never sent or saved to disk.")
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
            text: root.busy ? root.words("Revisando con aismell…", "Reviewing with aismell…") : root.status
            color: root.changes > 0 ? Color.menu.text : Color.menu.text
            opacity: root.changes > 0 ? 0.82 : 0.62
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }

          Text {
            visible: root.hasResult
            width: parent.width
            text: root.words("Índice de señales: ", "Signal index: ") + root.score + "/100 · " + root.changes + root.words(" hallazgo(s) concreto(s).", " concrete finding(s).")
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
                        root.findings = []
                        root.score = 0
                        root.changes = 0
                        root.status = root.words("Listo para revisar con aismell.", "Ready for an aismell review.")
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
                  text: root.words("señales de aismell", "aismell signals")
                  color: root.changes > 0 ? Style.selectedStateColor(Color.menu.text, Color.accent) : Color.menu.text
                  opacity: root.changes > 0 ? 1 : 0.56
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                Item {
                  width: parent.width
                  height: parent.height - y
                  ListView {
                    anchors.fill: parent
                    visible: root.findings.length > 0
                    clip: true
                    spacing: Style.spacing.sm
                    model: root.findings
                    delegate: Column {
                      required property var modelData
                      width: parent.width
                      spacing: Style.spacing.xs
                      Text {
                        width: parent.width
                        text: "“" + modelData.matched + "”"
                        color: Style.selectedStateColor(Color.menu.text, Color.accent)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.body
                        font.bold: true
                        wrapMode: Text.Wrap
                      }
                      Text {
                        width: parent.width
                        text: modelData.message
                        color: Color.menu.text
                        opacity: 0.76
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.Wrap
                      }
                      Text {
                        width: parent.width
                        text: "→ " + modelData.suggestion
                        color: Color.menu.text
                        opacity: 0.58
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.Wrap
                      }
                      Rectangle { width: parent.width; height: 1; color: Color.menu.border; opacity: 0.5 }
                    }
                  }
                  Text {
                    anchors.fill: parent
                    visible: root.hasResult && root.findings.length === 0
                    text: root.words("Nada fuerte que corregir. Tu texto queda como está.", "Nothing strong to correct. Your text stays as it is.")
                    color: Color.menu.text
                    opacity: 0.58
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.body
                    wrapMode: Text.Wrap
                  }
                  Text {
                    anchors.fill: parent
                    visible: !root.hasResult
                    text: root.words("Revisa el texto para ver señales reales de aismell y sugerencias concretas.", "Review the text to see real aismell signals and concrete suggestions.")
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
              text: root.words("revisar portapapeles", "review clipboard")
              tooltipText: root.words("Busca señales reales de aismell en lo que acabas de copiar.", "Find real aismell signals in what you just copied.")
              bordered: true
              active: !root.busy
              onClicked: root.reviewClipboard()
            }
            Button {
              id: cleanAction
              text: root.words("revisar texto", "review text")
              active: root.sourceText !== "" && !root.busy
              tooltipText: root.words("Busca señales de aismell en el texto de la izquierda.", "Find aismell signals in the text on the left.")
              onClicked: root.reviewText()
            }
            Item { width: parent.width - clipboardAction.width - cleanAction.width - primaryAction.width - parent.spacing * 2; height: 1 }
            Button {
              id: primaryAction
              visible: root.sourceText !== ""
              active: !root.busy
              selected: true
              text: root.words("copiar texto editado", "copy edited text")
              tooltipText: root.words("Copia el texto de la izquierda después de tu edición.", "Copy the text on the left after your edit.")
              onClicked: root.copyEditedText()
            }
          }
        }
      }
    }
}
