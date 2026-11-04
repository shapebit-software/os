// The colors, the font, and the sizes that every part shares.
pragma Singleton
import QtQuick

QtObject {
    // "Large text" in the accessibility menu scales every size.
    property real unit: 1

    readonly property string font: "Instrument Sans"
    readonly property color text: "#ffffff"
    readonly property color muted: Qt.rgba(1, 1, 1, 0.7)
    readonly property color faint: Qt.rgba(1, 1, 1, 0.55)
    readonly property color accent: "#8f4e82"
    readonly property color danger: "#ff9a8a"
    // The boot splash's background, which every step up to the desktop
    // shares (/usr/lib/bootc/kargs.d/30-splash.toml).
    readonly property color night: "#1f1a3c"
    // Surfaces let the backdrop show through.
    readonly property color field: Qt.rgba(0.07, 0.06, 0.11, 0.5)
    readonly property color panel: Qt.rgba(0.09, 0.08, 0.15, 0.94)
    readonly property color border: Qt.rgba(1, 1, 1, 0.22)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.12)
}
