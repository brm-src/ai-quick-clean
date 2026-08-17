import QtQuick
import qs.Commons
import qs.Ui

BarIconButton {
  id: root

  property string moduleName: "io.github.brm-src.ai-quick-clean"
  property var settings: ({})

  slotSize: bar ? bar.barSize : 27
  opticalSize: 16
  fontSize: 12
  text: "\uf040"
  tooltipText: root.isSpanish ? "Quitar palabrería de ia" : "strip ai waffle"
  readonly property bool isSpanish: Qt.locale().name.toLowerCase().startsWith("es")

  onPressed: function(button) {
    if (button === Qt.LeftButton && root.bar)
      root.bar.run("omarchy-shell shell toggle " + root.moduleName + " '{}'")
  }
}
