// The colors, the font, and the sizes that every part shares. The colors are
// the roles in Colors on dark surfaces (/usr/lib64/qt6/qml/Colors); before
// anyone signs in, the accent is the default one.
pragma Singleton
import QtQuick
import Colors

QtObject {
    // "Large text" in the accessibility menu scales every size.
    property real unit: 1

    readonly property string font: "Instrument Sans"
    readonly property color text: Colors.dark.textStrong
    readonly property color muted: Colors.dark.textMuted
    readonly property color faint: Colors.dark.textFaint
    readonly property color accent: Colors.accent(Colors.defaultAccent, 0)
    readonly property color danger: Colors.dark.danger
    // The boot splash's background, which every step up to the desktop
    // shares (/usr/lib/bootc/kargs.d/30-splash.toml).
    readonly property color night: Colors.night
    // Surfaces let the backdrop show through.
    readonly property color field: Colors.dark.surfaceSunken
    readonly property color panel: Colors.dark.surface
    readonly property color border: Colors.dark.line
    readonly property color hover: Colors.dark.hover
    // The ring around the picture of who signs in.
    readonly property color ring: Qt.alpha(Colors.dark.textStrong, 0.25)
}
