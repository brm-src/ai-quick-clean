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
  property var changes: []
  property string status: ""
  property var callback: null

  function words(es, en) { return root.isSpanish ? es : en }

  function errorText(payload) {
    switch (payload.errorCode) {
      case "empty": return root.words("Pega o escribe un texto primero.", "Paste or type some text first.")
      case "too-long": return root.words("Son demasiadas palabras. Prueba con menos de 3.000 caracteres.", "That is too long. Try under 3,000 characters.")
      case "rewrite-unavailable": return root.words("No hay conexión con el servicio. Intenta de nuevo.", "No connection to the service. Try again.")
      case "nothing-to-copy": return root.words("Todavía no hay nada que copiar.", "There is nothing to copy yet.")
      case "clipboard-failed": return root.words("No pude usar el portapapeles.", "I could not use the clipboard.")
      default: return root.words("No pude hacerlo.", "I could not do that.")
    }
  }

  readonly property string idleHint: words(
    "Pega tu texto y presiona limpiar.",
    "Paste your text and press clean.")

  function open() {
    root.opened = true
    root.hasResult = false
    root.cleanedText = ""
    root.changes = []
    root.status = root.idleHint
    // Whatever the person just copied is almost always what they want cleaned,
    // so it arrives already loaded instead of behind a second button.
    root.runHelper("read-clipboard", "", function(payload) {
      if (payload.ok && String(payload.source || "").trim() !== "") root.sourceText = String(payload.source)
    })
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
      root.status = root.words("No pude leer la respuesta.", "I could not read the response.")
      return
    }
    if (root.callback) root.callback(payload)
    root.callback = null
  }

  function cleanText() {
    if (!root.sourceText.trim()) {
      root.status = root.words("Pega o escribe un texto primero.", "Paste or type some text first.")
      return
    }
    root.status = root.words("Limpiando…", "Cleaning…")
    root.runHelper("rewrite-stdin", root.sourceText, function(payload) {
      if (!payload.ok) {
        root.hasResult = false
        root.cleanedText = ""
        root.changes = []
        root.status = root.errorText(payload)
        return
      }
      root.sourceText = String(payload.source || "")
      root.cleanedText = String(payload.text || "")
      root.changes = payload.changes || []
      root.hasResult = true
      root.status = root.changes.length > 0
        ? root.words("Listo. Compara y copia si te gusta.", "Done. Compare it and copy if you like it.")
        : root.words("Tu texto ya estaba limpio.", "Your text was already clean.")
    })
  }

  function copyCleanText() {
    root.runHelper("copy-stdin", root.cleanedText, function(payload) {
      root.status = payload.ok
        ? root.words("Copiado. Ya puedes pegarlo.", "Copied. You can paste it now.")
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
        root.status = root.words("No pude completar eso.", "I could not complete that.")
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

    // A layer surface is not a window, so the compositor's close-window bind
    // never reaches it. Escape and clicking the backdrop are the ways out, and
    // both live here so neither depends on which child holds focus.
    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.close()
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_W && (event.modifiers & Qt.MetaModifier)) {
          root.close()
          event.accepted = true
        }
      }
    }

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
        height: Math.min(Style.space(520), parent.height - Style.gapsOut * 2)
        anchors.centerIn: parent
        radius: Style.cornerRadius
        color: Color.menu.background
        borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
        padding: Style.spacing.panelPadding

        // Swallow clicks on the card so the backdrop's close does not fire.
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
                text: root.words("Quitar palabrería de IA", "Strip AI waffle")
                color: Color.menu.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Text {
                width: parent.width
                text: root.words(
                  "Le saca el relleno que suena a texto escrito por IA: frases de trámite, fórmulas repetidas y adjetivos de más. Conserva el mensaje, nombres, links y datos.",
                  "Removes the padding that makes text sound AI-written: stock phrases, repeated formulas, and extra adjectives. Keeps your message, names, links, and numbers.")
                color: Color.menu.text
                opacity: 0.66
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
              tooltipText: root.words("Cerrar (Esc)", "Close (Esc)")
              onClicked: root.close()
            }
          }

          Text {
            width: parent.width
            text: root.busy ? root.words("Limpiando…", "Cleaning…") : root.status
            color: Color.menu.text
            opacity: root.hasResult ? 0.82 : 0.62
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }

          Row {
            width: parent.width
            height: parent.height - y - actions.height - Style.spacing.md
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
                    Keys.onEscapePressed: root.close()
                    Keys.onPressed: function(event) {
                      if (event.key === Qt.Key_W && (event.modifiers & Qt.MetaModifier)) {
                        root.close()
                        event.accepted = true
                      }
                    }
                    onTextChanged: {
                      if (activeFocus && text !== root.sourceText) {
                        root.sourceText = text
                        root.hasResult = false
                        root.cleanedText = ""
                        root.changes = []
                        root.status = root.idleHint
                      }
                    }
                    Text {
                      visible: sourceEditor.text === "" && !sourceEditor.activeFocus
                      anchors.fill: parent
                      text: root.words("Pega un mensaje, correo o párrafo corto.", "Paste a short message, email, or paragraph.")
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
              color: root.hasResult ? Style.selectedFillFor(Color.menu.text, Color.accent) : Style.controlFill(false, false, Color.menu.text, Color.accent)
              borderSpec: root.hasResult ? Border.controlSpec("selected", Color.menu.text, Color.accent) : Border.controlSpec("normal", Color.menu.text, Color.accent)
              padding: Style.spacing.controlPaddingX

              Column {
                anchors.fill: parent
                anchors.topMargin: parent.contentTopInset
                anchors.rightMargin: parent.contentRightInset
                anchors.bottomMargin: parent.contentBottomInset
                anchors.leftMargin: parent.contentLeftInset
                spacing: Style.spacing.sm
                Text {
                  text: root.words("sin palabrería", "cleaned up")
                  color: root.hasResult ? Style.selectedStateColor(Color.menu.text, Color.accent) : Color.menu.text
                  opacity: root.hasResult ? 1 : 0.56
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
                    contentHeight: Math.max(height, cleanedTextItem.implicitHeight)
                    clip: true
                    Text {
                      id: cleanedTextItem
                      width: parent.width
                      text: root.cleanedText
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
                    text: root.words("Aquí aparecerá tu texto sin el relleno.", "Your text without the padding will appear here.")
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
              id: cleanAction
              text: root.words("limpiar", "clean")
              selected: !root.hasResult
              active: root.sourceText !== "" && !root.busy
              tooltipText: root.words("Quita el relleno del texto de la izquierda.", "Strip the padding from the text on the left.")
              onClicked: root.cleanText()
            }
            Button {
              id: copyAction
              visible: root.hasResult && root.cleanedText !== ""
              selected: true
              active: !root.busy
              text: root.words("copiar", "copy")
              tooltipText: root.words("Copia la versión limpia al portapapeles.", "Copy the cleaned version to the clipboard.")
              onClicked: root.copyCleanText()
            }
            Item {
              width: Math.max(0, parent.width - cleanAction.width - (copyAction.visible ? copyAction.width + parent.spacing : 0) - privacyNote.width - parent.spacing)
              height: 1
            }
            Text {
              id: privacyNote
              anchors.verticalCenter: parent.verticalCenter
              text: root.words("Se procesa en internet. No se guarda.", "Processed online. Not stored.")
              color: Color.menu.text
              opacity: 0.42
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }
    }
}
