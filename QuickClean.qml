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
  property var edits: []
  property string status: words("Copia algo y presiona limpiar.", "Copy something, then clean it.")
  property int changes: 0
  property var callback: null

  function words(es, en) { return root.isSpanish ? es : en }
  function errorText(payload) {
    switch (payload.errorCode) {
      case "empty": return root.words("Pega o escribe un texto antes de limpiar.", "Paste or type text before cleaning.")
      case "too-long": return root.words("Este atajo admite hasta 3.000 caracteres.", "This shortcut accepts up to 3,000 characters.")
      case "nothing-to-copy": return root.words("No hay una propuesta para copiar.", "There is no proposal to copy.")
      case "clipboard-failed": return root.words("No pude acceder al portapapeles.", "I could not access the clipboard.")
      default: return root.words("No pude completar esa acción.", "I could not complete that action.")
    }
  }

  function open() {
    root.opened = true
    root.hasResult = false
    root.sourceText = ""
    root.cleanedText = ""
    root.edits = []
    root.changes = 0
    root.status = root.words("Pega o escribe un texto corto.", "Paste or type a short text.")
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

  function cleanClipboard() {
    root.status = root.words("Leyendo y limpiando el portapapeles…", "Reading and cleaning the clipboard…")
    root.runHelper("clean-clipboard", "", function(payload) {
      root.applyCleanPayload(payload)
    })
  }

  function cleanText() {
    if (!root.sourceText.trim()) {
      root.status = root.words("Pega o escribe un texto antes de limpiar.", "Paste or type text before cleaning.")
      return
    }
    root.status = root.words("Buscando cambios seguros…", "Looking for safe changes…")
    root.runHelper("clean-stdin", root.sourceText, function(payload) {
      root.applyCleanPayload(payload)
    })
  }

  function applyCleanPayload(payload) {
    if (!payload.ok) {
      root.hasResult = false
      root.cleanedText = ""
      root.edits = []
      root.changes = 0
      root.status = root.errorText(payload)
      return
    }
    root.uiLanguage = payload.language === "es" ? "es" : "en"
    root.sourceText = String(payload.source || "")
    root.cleanedText = String(payload.text || "")
    root.edits = payload.edits || []
    root.changes = Number(payload.changes || 0)
    root.hasResult = true
    root.status = payload.message || root.words("Resultado listo.", "Result ready.")
  }

  function copyClean() {
    root.runHelper("copy-stdin", root.cleanedText, function(payload) {
      root.status = payload.ok
        ? root.words("Texto limpio copiado.", "Clean text copied.")
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
    Keys.onReturnPressed: if (event.modifiers & Qt.ControlModifier) root.cleanText()

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
                text: root.words("Mira el cambio antes de reemplazar el portapapeles.", "Review the change before replacing your clipboard.")
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
            text: root.busy ? root.words("Limpiando…", "Cleaning…") : root.status
            color: root.changes > 0 ? Color.menu.text : Color.menu.text
            opacity: root.changes > 0 ? 0.82 : 0.62
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }

          Text {
            visible: root.edits.length > 0
            width: parent.width
            text: root.words("Se quitará: ", "Will remove: ") + root.edits.map(function(edit) { return "“" + edit.removed + "”" }).join(" · ")
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
                        root.cleanedText = ""
                        root.edits = []
                        root.changes = 0
                        root.status = root.words("Listo para una pasada segura.", "Ready for a safe cleanup pass.")
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
                  text: root.words("versión limpia", "clean version")
                  color: root.changes > 0 ? Style.selectedStateColor(Color.menu.text, Color.accent) : Color.menu.text
                  opacity: root.changes > 0 ? 1 : 0.56
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                Flickable {
                  id: cleanedScroll
                  width: parent.width
                  height: parent.height - y
                  contentWidth: width
                  contentHeight: Math.max(height, cleanedEditor.height)
                  clip: true

                  TextEdit {
                    id: cleanedEditor
                    width: cleanedScroll.width
                    height: Math.max(cleanedScroll.height, contentHeight)
                    text: root.hasResult ? root.cleanedText : root.words("Limpia el texto para ver una propuesta.", "Clean the text to see a suggestion.")
                    color: root.changes > 0 ? Style.selectedStateColor(Color.menu.text, Color.accent) : Color.menu.text
                    opacity: root.hasResult ? 1 : 0.48
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.body
                    wrapMode: TextEdit.Wrap
                    readOnly: true
                    selectByMouse: true
                    textFormat: TextEdit.PlainText
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
              text: root.words("usar portapapeles", "use clipboard")
              tooltipText: root.words("Limpia lo que acabas de copiar.", "Clean what you just copied.")
              bordered: true
              active: !root.busy
              onClicked: root.cleanClipboard()
            }
            Button {
              id: cleanAction
              text: root.words("limpiar texto", "clean text")
              active: root.sourceText !== "" && !root.busy
              tooltipText: root.words("Limpia el texto de la izquierda.", "Clean the text on the left.")
              onClicked: root.cleanText()
            }
            Item { width: parent.width - clipboardAction.width - cleanAction.width - primaryAction.width - parent.spacing * 2; height: 1 }
            Button {
              id: primaryAction
              visible: root.changes > 0
              active: !root.busy
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
