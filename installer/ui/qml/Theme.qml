// The colors, fonts, and sizes every page shares.
pragma Singleton
import QtQuick

QtObject {
    readonly property color background: "#0c0e17"
    readonly property color panel: "#161821"
    readonly property color border: "#2b2e3a"
    readonly property color selected: "#20263a"
    readonly property color text: "#e9eaf0"
    readonly property color muted: "#a3a6b1"
    readonly property color faint: "#666a77"
    readonly property color accent: "#2b7f96"
    readonly property color link: "#56b8cd"
    readonly property color danger: "#b23040"
    readonly property color track: "#262933"

    // Small technical details: identifiers, sizes, times.
    readonly property string mono: "monospace"
    readonly property int small: 11
    readonly property int body: 14
}
