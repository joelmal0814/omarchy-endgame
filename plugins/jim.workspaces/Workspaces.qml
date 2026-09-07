import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Clone of omarchy.workspaces that can render theme-provided glyphs.
//
// A theme ships a [branding] section in its shell.toml (Omarchy merges
// shell.branding.toml into it) with:
//   workspace-glyphs        = "♔ ♕ ♖ ♗ ♘ ♙"   one glyph per workspace id
//   workspace-active-glyphs = "♚ ♛ ♜ ♝ ♞ ♟"   optional, shown when focused
//   workspace-active-color  = "#A7C59A"        optional, defaults to accent
// Without those keys the widget behaves exactly like the stock one.
BarWidget {
  id: root
  moduleName: "omarchy.workspaces"


  // shell.toml values are ASCII-only (see the theme's shell.branding.toml);
  // glyphs arrive as \uXXXX escapes and are decoded here.
  function decodeEscapes(value) {
    return String(value || "").replace(/\\u\{?([0-9a-fA-F]{4,6})\}?/g, function(match, hex) {
      return String.fromCodePoint(parseInt(hex, 16))
    })
  }

  function glyphList(key) {
    var raw = decodeEscapes(Color.shellValues[key]).trim()
    return raw.length > 0 ? raw.split(/\s+/) : []
  }

  readonly property var glyphs: glyphList("branding.workspace-glyphs")
  readonly property var activeGlyphs: glyphList("branding.workspace-active-glyphs")
  readonly property bool useGlyphs: glyphs.length > 0
  readonly property string activeColorToken: String(Color.shellValues["branding.workspace-active-color"] || "").trim()
  readonly property color activeGlyphColor: activeColorToken.length > 0 ? Color.flatColor(activeColorToken, Color.accent) : Color.accent

  function labelFor(id, focused) {
    if (root.useGlyphs) {
      if (id >= 1 && id <= root.glyphs.length) {
        if (focused && id <= root.activeGlyphs.length && root.activeGlyphs[id - 1]) return root.activeGlyphs[id - 1]
        return root.glyphs[id - 1]
      }
      return id === 10 ? "0" : String(id)
    }
    return focused ? "\uDB85\uDCFB" : (id === 10 ? "0" : String(id))
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: root.labelFor(modelData, focused)
        fontSize: root.useGlyphs ? Style.font.title : Style.font.body
        active: root.useGlyphs && focused
        activeColor: root.activeGlyphColor
        opacity: occupied || focused ? 1 : (root.useGlyphs ? 0.42 : 0.5)
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        tooltipText: root.useGlyphs ? "Workspace " + modelData : ""
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
