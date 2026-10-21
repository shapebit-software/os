// The colors, the fonts, and the sizes that every part of the shell shares.
pragma Singleton
import QtQuick

QtObject {
    readonly property string font: "Instrument Sans"
    readonly property string mono: "JetBrains Mono"
    readonly property color text: "#e6e8eb"
    readonly property color accent: "#007890"
    // The bar's glass; the compositor blurs what shows through.
    readonly property color barGlass: Qt.rgba(0.047, 0.047, 0.094, 0.5)
    // The space between tiles, and between tiles and the screen edges; the
    // compositor uses the same value (compositor/hyprland.lua).
    readonly property int gap: 10
    readonly property int barHeight: 40
}
