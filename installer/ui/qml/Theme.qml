// The colors, fonts, and sizes every page shares. The colors are the roles on
// dark surfaces, as on the login screen, from Colors: the system's one list of
// colors, which the installer medium carries in Qt's QML folder
// (image/rootfs/usr/lib64/qt6/qml/Colors in the source). Before anyone signs
// in, the accent is the default one.
pragma Singleton
import QtQuick
import Colors

QtObject {
    readonly property color background: Colors.night
    readonly property color panel: Colors.dark.surface
    readonly property color field: Colors.dark.surfaceSunken
    readonly property color border: Colors.dark.line
    readonly property color hover: Colors.dark.hover
    readonly property color selected: Qt.alpha(accent, 0.4)
    readonly property color text: Colors.dark.textStrong
    readonly property color muted: Colors.dark.textMuted
    readonly property color faint: Colors.dark.textFaint
    readonly property color accent: Colors.accent(Colors.defaultAccent, 0)
    readonly property color textOnAccent: Colors.dark.textOnAccent
    // The accent as text, which reads on dark surfaces.
    readonly property color link: Colors.accentInk(Colors.defaultAccent, 0)
    // Errors as text, and fills behind light text, such as Erase.
    readonly property color danger: Colors.dark.danger
    readonly property color dangerFill: Colors.dark.dangerFill
    readonly property color track: Colors.dark.fill

    // Small technical details: identifiers, sizes, times.
    readonly property string mono: "monospace"
    readonly property int small: 11
    readonly property int body: 14
}
