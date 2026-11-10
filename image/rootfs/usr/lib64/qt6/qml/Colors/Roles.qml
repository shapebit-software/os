// The roles that colors play on a kind of surface, light or dark, which
// /usr/share/colors/colors.toml fills for each (Colors.light, Colors.dark). A
// set leaves out the roles that nothing on its surfaces needs yet.
import QtQuick

QtObject {
    // Behind everything, and the surfaces on it: raised, such as cards and
    // panels, and sunken, such as sidebars and fields.
    property color background
    property color surface
    property color surfaceSunken
    // Tiles, chips, and tracks; what is under the pointer, and more of it on
    // a sunken surface.
    property color fill
    property color hover
    property color hoverStrong
    // Lines: around surfaces, between rows, around fields, under the
    // pointer, and around what cannot be used.
    property color line
    property color lineSoft
    property color lineStrong
    property color lineHover
    property color disabled
    // Text, from the most to the least prominent.
    property color textStrong
    property color textBody
    property color textSoft
    property color textMuted
    property color textFaint
    // Warnings as text, and fills behind light text.
    property color danger
    property color dangerFill
    // Text and icons on the accent.
    property color textOnAccent
}
