import QtQuick

// Plain bar button. No qs.Ui imports on purpose: third-party bar widgets loaded
// through Qt.createComponent can trip over Omarchy's internal Style/BarWidget
// singletons. A bare Item is enough and matches the public bar-widget contract.
Item {
  id: root

  property var bar: null
  property string moduleName: "io.github.brm-src.aismell-quick-clean"
  property var settings: ({})
  readonly property bool isSpanish: Qt.locale().name.toLowerCase().startsWith("es")
  readonly property bool vertical: bar ? bar.vertical : false

  implicitWidth: vertical ? (bar ? bar.barSize : 28) : 26
  implicitHeight: vertical ? 26 : (bar ? bar.barSize : 26)

  Rectangle {
    id: hoverBg
    anchors.fill: parent
    radius: 6
    color: mouse.containsMouse ? "#2a202b" : "transparent"
  }

  Text {
    anchors.centerIn: parent
    text: "\uf02d"
    color: root.bar ? root.bar.foreground : "white"
    font.family: root.bar ? root.bar.fontFamily : "monospace"
    font.pixelSize: 12
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onClicked: {
      if (root.bar) root.bar.run("omarchy-shell shell toggle " + root.moduleName + " '{}'")
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.isSpanish ? "Quitar palabrería de IA" : "Strip AI waffle")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
