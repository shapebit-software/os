// The colors, the fonts, and the sizes that every part of the shell shares.
pragma Singleton
import QtQuick

QtObject {
    readonly property string font: "Instrument Sans"
    readonly property string mono: "JetBrains Mono"
    readonly property color text: "#e6e8eb"
    readonly property color accent: Settings.accents[Settings.accent] ?? "#007890"
    // The bar's glass, which the compositor blurs what shows through, or a
    // solid color with reduced transparency.
    readonly property color barGlass: Settings.reduceTransparency ? "#11101a" : Qt.rgba(0.047, 0.047, 0.094, 0.5)
    // Panels: their body, edge (also of fields in them), and entries under
    // the pointer.
    readonly property color panel: Qt.rgba(0.153, 0.157, 0.188, Settings.reduceTransparency ? 1 : 0.96)
    readonly property color panelBorder: "#45484d"
    readonly property color panelHover: "#35383e"
    // Warnings, such as muted devices: lines, and areas behind light text.
    readonly property color danger: "#f05653"
    readonly property color dangerFill: "#b63132"
    // The space between tiles, and between tiles and the screen edges; the
    // shell sets the compositor's to the same (Settings.qml).
    readonly property int gap: Settings.gapSize
    readonly property int barHeight: 40
    // The height of the workspace strip at the bottom of the screen.
    readonly property int stripHeight: 60
}
