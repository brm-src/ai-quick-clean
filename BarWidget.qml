import QtQuick
import qs.Ui

// Bar button for aismell quick clean. The panel half lives in QuickClean.qml;
// this is only a launcher, so the panel stays the single place that owns state.
BarWidget {
  id: root
  moduleName: "io.github.brm-src.aismell-quick-clean"

  readonly property bool isSpanish: Qt.locale().name.toLowerCase().startsWith("es")

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf044"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: root.isSpanish ? "Reescribir texto con aismell" : "Rewrite text with aismell"
    onPressed: {
      if (root.bar) root.bar.run("omarchy-shell shell toggle " + root.moduleName + " '{}'")
    }
  }
}
