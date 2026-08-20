import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  readonly property string pluginId: "io.github.brm-src.ai-quick-clean"
  readonly property bool isSpanish: uiLanguage === "es"
  readonly property int cardWidth: Math.min(Style.space(560), panel.width - Style.gapsOut * 2)
  property bool opened: false
  property bool busy: false
  property bool hasResult: false
  property bool backdropReady: false
  property string uiLanguage: Qt.locale().name.toLowerCase().startsWith("es") ? "es" : "en"
  property string mode: "clean"  // clean, improve, bibliography
  property string sourceText: ""
  property string cleanedText: ""
  property var changes: []
  property var report: ({})
  property string status: ""
  property var callback: null

  function words(es, en) { return root.isSpanish ? es : en }

  function errorText(payload) {
    if (root.mode === "bibliography") {
      switch (payload.errorCode) {
        case "empty": return root.words("Pega una bibliografía primero.", "Paste a bibliography first.")
        case "too-long": return root.words("Es demasiado larga. Usa menos de 12.000 caracteres.", "That is too long. Use fewer than 12,000 characters.")
        case "check-unavailable": return root.words("No hay conexión con el servicio. Intenta de nuevo.", "The service is unavailable. Try again.")
        default: return root.words("No pude revisar la bibliografía.", "I could not check the bibliography.")
      }
    } else {
      switch (payload.errorCode) {
        case "empty": return root.words("Pega o escribe un texto primero.", "Paste or type some text first.")
        case "too-long": return root.words("Son demasiadas palabras. Prueba con menos de 3.000 caracteres.", "That is too long. Try under 3,000 characters.")
        case "rewrite-unavailable": return root.words("No hay conexión con el servicio. Intenta de nuevo.", "No connection to the service. Try again.")
        case "nothing-to-copy": return root.words("Todavía no hay nada que copiar.", "There is nothing to copy yet.")
        case "clipboard-failed": return root.words("No pude usar el portapapeles.", "I could not use the clipboard.")
        default: return root.words("No pude hacerlo.", "I could not do that.")
      }
    }
  }

  readonly property var titles: ({
    clean: root.words("ai quick clean", "ai quick clean"),
    improve: root.words("ai quick clean", "ai quick clean"),
    bibliography: root.words("revisar bibliografía", "check bibliography")
  })

  readonly property var hints: ({
    clean: root.words("Pega un texto y presiona limpiar. Queda más directo y sin relleno.", "Paste some text and press clean. It gets more direct, without the padding."),
    improve: root.words("Pega un texto y presiona mejorar. Lo deja más claro y con mejor redacción.", "Paste some text and press improve. It gets clearer and better written."),
    bibliography: root.words("Pega tu lista de referencias y presiona revisar bibliografía. Busca duplicados, entradas incompletas y coincidencias en Crossref y OpenAlex.", "Paste your reference list and press check bibliography. It looks for duplicates, incomplete entries, and matches on Crossref and OpenAlex.")
  })

  readonly property var idleHint: root.hints[root.mode]

  function setMode(newMode) {
    if (root.mode === newMode) return
    root.mode = newMode
    root.hasResult = false
    root.cleanedText = ""
    root.changes = []
    root.report = ({})
    root.status = root.idleHint
    if (newMode === "clean" || newMode === "improve") {
      root.runHelper("read-clipboard", "", function(payload) {
        if (payload.ok && String(payload.source || "").trim() !== "") root.sourceText = String(payload.source)
      })
    }
  }

  function open() {
    root.opened = true
    root.backdropReady = false
    backdropGuard.restart()
    root.hasResult = false
    root.cleanedText = ""
    root.changes = []
    root.report = ({})
    root.status = root.idleHint
    if (root.mode === "clean" || root.mode === "improve") {
      root.runHelper("read-clipboard", "", function(payload) {
        if (payload.ok && String(payload.source || "").trim() !== "") root.sourceText = String(payload.source)
      })
    }
  }

  function close() {
    root.opened = false
    root.backdropReady = false
    backdropGuard.stop()
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
    try { payload = JSON.parse(String(raw || "{}")) }
    catch (error) {
      root.status = root.words("No pude leer la respuesta.", "I could not read the response.")
      return
    }
    if (root.callback) root.callback(payload)
    root.callback = null
  }

  function changesSummary() {
    return root.changes.slice(0, 3).map(function(item) { return "• " + String(item) }).join("\n")
  }

  function cleanText(mode) {
    mode = mode === "improve" ? "improve" : "clean"
    if (!root.sourceText.trim()) {
      root.status = root.words("Pega o escribe un texto primero.", "Paste or type some text first.")
      return
    }
    root.status = mode === "improve"
      ? root.words("Mejorando el texto…", "Improving the text…")
      : root.words("Analizando y limpiando…", "Analyzing and cleaning…")
    root.runHelper(mode === "improve" ? "rewrite-stdin-improve" : "rewrite-stdin", root.sourceText, function(payload) {
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
        ? root.words("Listo · " + root.changes.length + " cambios. Compara y copia si te gusta.", "Done · " + root.changes.length + " changes. Compare it and copy if you like it.")
        : root.words("No encontré cambios claros.", "I found no clear changes.")
    })
  }

  function checkBibliography() {
    if (!root.sourceText.trim()) {
      root.status = root.words("Pega una bibliografía primero.", "Paste a bibliography first.")
      return
    }
    root.status = root.words("Buscando coincidencias en Crossref y OpenAlex…", "Searching for matches in Crossref and OpenAlex…")
    root.runHelper("check-stdin", root.sourceText, function(payload) {
      if (!payload.ok) {
        root.hasResult = false
        root.report = ({})
        root.status = root.errorText(payload)
        return
      }
      root.report = payload.report || ({})
      root.hasResult = true
      root.status = root.words("Revisión lista. Lee los hallazgos.", "Check complete. Read the findings.")
    })
  }

  function copyCleanText() {
    root.runHelper("copy-stdin", root.cleanedText, function(payload) {
      root.status = payload.ok
        ? root.words("Copiado. Ya puedes pegarlo.", "Copied. You can paste it now.")
        : root.errorText(payload)
    })
  }

  function lookupLabel(item) {
    var status = item.status === "found"
      ? root.words("encontrada", "found")
      : item.status === "possible"
        ? root.words("posible", "possible")
        : item.status === "not-found"
          ? root.words("sin coincidencia", "no match")
          : root.words("servicio no disponible", "service unavailable")
    var source = item.match ? item.match.source : (item.sources || []).map(function(source) { return source.source }).join(" + ")
    var unavailable = (item.sources || []).filter(function(source) { return source.status === "unavailable" }).map(function(source) { return source.source })
    var responded = (item.sources || []).filter(function(source) { return source.status === "responded" && (!item.match || source.source !== item.match.source) }).map(function(source) { return source.source })
    if (unavailable.length) source += root.words(" · " + unavailable.join(" + ") + " no disponible", " · " + unavailable.join(" + ") + " unavailable")
    if (responded.length) source += root.words(" · " + responded.join(" + ") + " respondió", " · " + responded.join(" + ") + " responded")
    return root.words("Entrada ", "Entry ") + item.entry + " · " + status + " · " + source + (item.scholarUrl ? " · Google Scholar ↗" : "")
  }

  function statusLabel() {
    if (!root.hasReport) return ""
    if (root.report.status === "attention") return root.words("necesita atención", "needs attention")
    if (root.report.status === "review") return root.words("conviene revisar", "worth reviewing")
    return root.words("sin problemas claros", "no clear problems")
  }

  function findingLabel(item) {
    var number = item.entry ? (root.words("Entrada ", "Entry ") + item.entry + " · ") : ""
    return number + String(item.message || "")
  }

  function lookupSummary() {
    var lookup = root.report.lookup || ({})
    var results = lookup.results || []
    var found = results.filter(function(item) { return item.status === "found" }).length
    var possible = results.filter(function(item) { return item.status === "possible" }).length
    return root.words(
      "Búsqueda externa: " + found + " coincidencias" + (possible ? " · " + possible + " posibles" : "") + " · Crossref + OpenAlex · Google Scholar ↗",
      "External search: " + found + " matches" + (possible ? " · " + possible + " possible" : "") + " · Crossref + OpenAlex · Google Scholar ↗"
    )
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

  Timer {
    id: backdropGuard
    interval: 200
    repeat: false
    onTriggered: root.backdropReady = true
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
      color: "transparent"
      MouseArea {
        anchors.fill: parent
        enabled: root.backdropReady
        onClicked: root.close()
      }
    }

    BorderSurface {
        id: card
        width: root.cardWidth
        height: Math.min(root.mode === "bibliography" ? Style.space(560) : Style.space(520), parent.height - Style.bar.sizeHorizontal - Style.gapsOut * 3)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Style.bar.sizeHorizontal + Style.gapsOut
        anchors.rightMargin: Style.gapsOut
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
                text: root.titles[root.mode]
                color: Color.menu.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.title
                font.bold: true
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
            text: root.status
            color: Color.menu.text
            opacity: root.hasResult ? 0.82 : 0.62
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }

          Item {
            id: progressBar
            width: parent.width
            height: Style.space(5)
            visible: root.busy
            clip: true

            Rectangle {
              anchors.fill: parent
              radius: height / 2
              color: Color.menu.text
              opacity: 0.14
            }
            Rectangle {
              id: progressIndicator
              width: Math.max(Style.space(72), parent.width * 0.28)
              height: parent.height
              radius: height / 2
              color: Color.accent
              x: -width

              SequentialAnimation on x {
                running: root.busy
                loops: Animation.Infinite
                NumberAnimation { from: -progressIndicator.width; to: progressBar.width; duration: 900; easing.type: Easing.InOutQuad }
                PauseAnimation { duration: 120 }
              }
            }
          }

          Text {
            width: parent.width
            visible: root.mode !== "bibliography" && root.hasResult && root.changes.length > 0
            text: root.changesSummary()
            color: Color.menu.text
            opacity: 0.58
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
          }

          Row {
            width: parent.width
            height: Math.max(80, parent.height - y - actions.height - bibSeparator.height - bibRow.height - Style.spacing.md * 3)
            spacing: Style.spacing.md

            // BIBLIOGRAPHY MODE - single column
            BorderSurface {
              visible: root.mode === "bibliography"
              width: parent.width
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

                TextEdit {
                  id: bibSourceEditor
                  width: parent.width
                  height: Math.min(Style.space(200), parent.height * 0.5)
                  text: root.sourceText
                  color: Color.menu.text
                  opacity: 0.9
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.body
                  wrapMode: TextEdit.Wrap
                  selectByMouse: true
                  textFormat: TextEdit.PlainText
                  Keys.onEscapePressed: root.close()
                  onTextChanged: {
                    if (activeFocus && text !== root.sourceText) {
                      root.sourceText = text
                      root.hasResult = false
                      root.report = ({})
                      root.status = root.idleHint
                    }
                  }
                  Text {
                    visible: bibSourceEditor.text === "" && !bibSourceEditor.activeFocus
                    anchors.fill: parent
                    text: root.words("Una entrada por línea o separada por espacios en blanco.", "One entry per line or separated by blank lines.")
                    color: Color.menu.text
                    opacity: 0.45
                    font: bibSourceEditor.font
                    wrapMode: Text.Wrap
                  }
                }

                Flickable {
                  width: parent.width
                  height: parent.height - y
                  contentWidth: width
                  contentHeight: resultsColumn.implicitHeight
                  clip: true
                  visible: root.hasResult

                  Column {
                    id: resultsColumn
                    width: parent.width
                    spacing: Style.spacing.sm

                    Row {
                      width: parent.width
                      spacing: Style.spacing.md
                      Text {
                        text: root.hasResult ? String(root.report.score || 0) + "/100" : ""
                        color: Color.accent
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.title
                        font.bold: true
                      }
                      Column {
                        width: parent.width - 100
                        Text {
                          text: root.statusLabel()
                          color: Color.menu.text
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.font.body
                          font.bold: true
                        }
                        Text {
                          text: root.words(
                            String(root.report.entryCount || 0) + " entradas · " + String((root.report.findings || []).length) + " hallazgos",
                            String(root.report.entryCount || 0) + " entries · " + String((root.report.findings || []).length) + " findings")
                          color: Color.menu.text
                          opacity: 0.62
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.font.bodySmall
                        }
                      }
                    }

                    Text {
                      width: parent.width
                      visible: Boolean(root.report && root.report.analysis && root.report.analysis.truncated)
                      text: root.words("El análisis lingüístico cubre los primeros 3.000 caracteres; las comprobaciones estructurales cubren todo el texto.", "Linguistic analysis covers the first 3,000 characters; structural checks cover the full text.")
                      color: Color.menu.text
                      opacity: 0.58
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.Wrap
                    }

                    Text {
                      width: parent.width
                      visible: root.report.lookup !== undefined
                      text: root.lookupSummary()
                      color: Color.accent
                      opacity: 0.82
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.font.bodySmall
                      wrapMode: Text.Wrap
                    }

                    Repeater {
                      model: root.report.lookup ? (root.report.lookup.results || []) : []
                      delegate: Item {
                        width: resultsColumn.width
                        height: resultLabel.implicitHeight
                        Text {
                          id: resultLabel
                          width: parent.width
                          text: "• " + root.lookupLabel(modelData)
                          color: modelData.status === "found" ? Color.accent : Color.menu.text
                          opacity: modelData.status === "found" ? 0.92 : 0.62
                          font.family: Style.font.menuFamily
                          font.pixelSize: Style.font.caption
                          wrapMode: Text.Wrap
                        }
                        MouseArea {
                          anchors.fill: parent
                          enabled: modelData.scholarUrl !== ""
                          cursorShape: Qt.PointingHandCursor
                          onClicked: Qt.openUrlExternally(modelData.scholarUrl)
                        }
                      }
                    }

                    Repeater {
                      model: root.report.findings || []
                      delegate: Text {
                        width: resultsColumn.width
                        text: "• " + root.findingLabel(modelData)
                        color: modelData.severity === "high" ? Color.accent : Color.menu.text
                        opacity: modelData.severity === "high" ? 0.95 : 0.76
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.Wrap
                      }
                    }
                  }
                }
              }
            }

            // CLEAN / IMPROVE MODE - two columns
            BorderSurface {
              visible: root.mode !== "bibliography"
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
              visible: root.mode !== "bibliography"
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
              selected: root.mode === "clean"
              active: root.sourceText !== "" && !root.busy
              tooltipText: root.words("Quita el relleno de ia y mejora la redacción.", "Removes ai filler and improves wording.")
              onClicked: {
                root.setMode("clean")
                if (root.sourceText !== "") root.cleanText("clean")
              }
            }
            Button {
              id: improveAction
              text: root.words("mejorar", "improve")
              selected: root.mode === "improve"
              active: root.sourceText !== "" && !root.busy
              tooltipText: root.words("Edición más visible: corta fórmulas, redundancias y tono institucional.", "More visible edit: cuts boilerplate, repetition, and institutional tone.")
              onClicked: {
                root.setMode("improve")
                if (root.sourceText !== "") root.cleanText("improve")
              }
            }

            Item {
              id: actionSpacer
              width: Math.max(0, parent.width - cleanAction.width - improveAction.width - (copyAction.visible ? copyAction.width + parent.spacing : 0) - poweredBy.width - parent.spacing * 2)
              height: 1
            }

            Button {
              id: copyAction
              visible: root.mode !== "bibliography" && root.hasResult && root.cleanedText !== ""
              selected: true
              active: !root.busy
              text: root.words("copiar", "copy")
              tooltipText: root.words("Copia la versión limpia al portapapeles.", "Copy the cleaned version to the clipboard.")
              onClicked: root.copyCleanText()
            }
            Item {
              id: poweredBy
              width: Style.space(150)
              height: parent.height

              Text {
                id: poweredByLabel
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "powered by: aismell.me"
                color: Color.menu.text
                opacity: 0.62
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                anchors.fill: poweredByLabel
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally("https://aismell.me")
              }
            }
          }

          Rectangle {
            id: bibSeparator
            width: parent.width
            height: 1
            color: Color.menu.text
            opacity: 0.12
          }

          Row {
            id: bibRow
            width: parent.width
            spacing: Style.spacing.sm

            Button {
              id: checkAction
              text: root.words("revisar bibliografía", "check bibliography")
              selected: root.mode === "bibliography"
              active: root.sourceText.trim() !== "" && !root.busy
              fontSize: Style.font.bodySmall
              tooltipText: root.words("Busca duplicados, entradas incompletas y coincidencias en Crossref y OpenAlex.", "Looks for duplicates, incomplete entries, and matches on Crossref and OpenAlex.")
              onClicked: {
                root.setMode("bibliography")
                if (root.sourceText.trim() !== "") root.checkBibliography()
              }
            }
          }

        }
      }
    }
  }
