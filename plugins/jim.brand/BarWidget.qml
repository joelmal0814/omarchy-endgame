import QtQuick
import qs.Commons
import qs.Ui

// Drop-in replacement for the omarchy.menu bar button. When the active theme
// defines [branding] bar = "..." in its shell.toml the label is shown instead
// of the Omarchy logo; otherwise this is visually identical to the stock
// button. Clicks behave like omarchy.menu: left = menu, right = terminal.
BarWidget {
  id: root
  moduleName: "jim.brand"


  // shell.toml values are ASCII-only (see the theme's shell.branding.toml);
  // glyphs arrive as \uXXXX escapes and are decoded here.
  function decodeEscapes(value) {
    return String(value || "").replace(/\\u\{?([0-9a-fA-F]{4,6})\}?/g, function(match, hex) {
      return String.fromCodePoint(parseInt(hex, 16))
    })
  }

  readonly property string brand: decodeEscapes(Color.shellValues["branding.bar"]).trim()
  readonly property bool hasBrand: brand.length > 0
  readonly property string brandColorToken: String(Color.shellValues["branding.bar-color"] || "").trim()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.hasBrand ? root.brand : "\ue900"
    fontFamily: root.hasBrand ? (root.bar ? root.bar.fontFamily : Style.font.family) : "omarchy"
    fontSize: Style.font.body
    active: root.hasBrand && root.brandColorToken.length > 0
    activeColor: root.brandColorToken.length > 0 ? Color.flatColor(root.brandColorToken, Color.accent) : Color.accent
    horizontalMargin: root.hasBrand ? 9 : 7.5
    tooltipText: root.hasBrand ? "Omarchy menu" : ""
    onPressed: function(mouseButton) {
      if (!root.bar) return
      if (mouseButton === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    }
  }
}
