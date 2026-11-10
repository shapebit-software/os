// The colors, the fonts, and the sizes that every part of the shell shares.
// The colors are roles taken from Colors, the QML module of the system's colors
// (image/rootfs/usr/share/colors/colors.toml); no other file of the shell names
// a color (tests/unit/test_colors.py).
pragma Singleton
import QtQuick
import Colors

QtObject {
    readonly property string font: "Instrument Sans"
    readonly property string mono: "JetBrains Mono"

    // The accent (Settings.accent): fills with light text on them, a pale
    // tint for what is selected on light surfaces, and text on dark ones.
    readonly property color accent: Colors.accent(Settings.accent, Settings.accentHue)
    readonly property color accentSoft: Colors.accentSoft(Settings.accent, Settings.accentHue)
    readonly property color accentInk: Colors.accentInk(Settings.accent, Settings.accentHue)
    // The accents to choose from, by name, and any accent, such as a custom
    // one by its hue.
    readonly property var accents: Object.keys(Colors.accents)
    function accentOf(name: string, hue: real): color {
        return Colors.accent(name, hue);
    }

    // The windows, such as Settings. Only light surfaces exist so far; a dark
    // color scheme would pick Colors.dark's roles here.
    readonly property Roles scheme: Colors.light
    readonly property color background: scheme.background
    readonly property color surface: scheme.surface
    readonly property color surfaceSunken: scheme.surfaceSunken
    readonly property color fill: scheme.fill
    readonly property color hover: scheme.hover
    readonly property color hoverStrong: scheme.hoverStrong
    readonly property color line: scheme.line
    readonly property color lineSoft: scheme.lineSoft
    readonly property color lineStrong: scheme.lineStrong
    readonly property color lineHover: scheme.lineHover
    readonly property color disabled: scheme.disabled
    readonly property color textStrong: scheme.textStrong
    readonly property color textBody: scheme.textBody
    readonly property color textSoft: scheme.textSoft
    readonly property color textMuted: scheme.textMuted
    readonly property color textFaint: scheme.textFaint
    readonly property color dangerInk: scheme.danger
    readonly property color textOnAccent: scheme.textOnAccent

    // The lock screen's glass over the backdrop, as on the login screen.
    readonly property Roles dark: Colors.dark

    // Text on the bars and on what is dark behind them, and the brightest
    // marks there, such as icons.
    readonly property color text: Colors.grey150
    readonly property color textBright: Colors.grey50
    readonly property color textOnDark: Colors.grey0
    // The bars' fill (Settings.barBackground): glass, which the compositor
    // blurs what shows through, a solid color, or nothing.
    readonly property color barFill: Settings.barBackground === "Solid" ? Colors.nightBar
        : Settings.barBackground === "Glass" ? Qt.alpha(Colors.nightBarGlass, 0.5) : "transparent"
    // The background behind the wallpaper, the same as the boot splash's.
    readonly property color night: Colors.night
    // What covers the screen the moment it locks, before the lock screen.
    readonly property color blackout: Colors.black

    // Popovers, the panels that open from the bars, as in the demo: light
    // glass from top to bottom with a thin ring, text in a dark violet, and
    // a violet veil for tiles, fields, and what is under the pointer.
    readonly property color popoverTop: Qt.alpha(Colors.lavender50, 0.95)
    readonly property color popoverBottom: Qt.alpha(Colors.lavender100, 0.93)
    readonly property color popoverRing: Qt.alpha(Colors.inkVeil, 0.14)
    readonly property color popoverHover: Colors.lavender50
    readonly property color ink: Colors.ink
    readonly property color inkSoft: Colors.inkSoft
    readonly property color inkMuted: Colors.inkMuted
    readonly property color inkFaint: Colors.inkFaint
    function veil(alpha: real): color {
        return Qt.alpha(Colors.inkVeil, alpha);
    }
    // A dark violet over a popover, behind a panel of its own.
    function inkScrim(alpha: real): color {
        return Qt.alpha(Colors.inkDeep, alpha);
    }
    // The capture panel's light fill, its tracks, and what cannot be used yet.
    readonly property color paneFill: Colors.lavender150
    readonly property color paneTrack: Colors.lavender250
    readonly property color paneDisabled: Colors.lavender500

    // White over what is dark: lines, fills, and what is under the pointer.
    function sheen(alpha: real): color {
        return Qt.alpha(Colors.grey0, alpha);
    }
    // What dims the screen behind a dialog or a capture.
    function scrim(alpha: real): color {
        return Qt.alpha(Colors.nightScrim, alpha);
    }
    // Dark violet glass over the backdrop or the wallpaper.
    function glass(alpha: real): color {
        return Qt.alpha(Colors.nightGlass, alpha);
    }
    // Near black under glass that the compositor blurs.
    function shade(alpha: real): color {
        return Qt.alpha(Colors.nightShade, alpha);
    }
    // Controls that float over windows, such as leaving full screen.
    function hud(alpha: real): color {
        return Qt.alpha(Colors.nightSlate, alpha);
    }
    // Shadows under popovers, pills, and handles.
    function shadow(alpha: real): color {
        return Qt.alpha(Colors.inkShadow, alpha);
    }
    // Light marks over the dark workspace maps, by how bright.
    readonly property color mapLight: Colors.grey25
    readonly property color mapMid: Colors.grey400
    readonly property color mapDim: Colors.grey500
    readonly property color mapGlow: Colors.grey200

    // Warnings: lines and areas on dark, such as muted devices; fills behind
    // light text; and the recording button.
    readonly property color danger: Colors.red400
    readonly property color dangerFill: Colors.red600
    readonly property color record: Colors.red500
    // The pens that mark up a screenshot; the last but one is also the text
    // on the light pens.
    readonly property var pens: Colors.pens
    readonly property color penInk: Colors.pens[3]

    // The space between tiles, and between tiles and the screen edges; the
    // shell sets the compositor's to the same (Settings.qml).
    readonly property int gap: Settings.gapSize
    readonly property int barHeight: 40
    // The height of the workspace strip at the bottom of the screen.
    readonly property int stripHeight: 60
    // Rounded window corners round the shell's tiles too: tabs, the cells of
    // the maps, and the applications in Apps.
    readonly property bool rounded: Settings.windowCorners === "Rounded"

    // A color from OKLCH, for colors that the person picks, such as the
    // wallpaper's gradient.
    function oklch(l: real, c: real, h: real, alpha: real): color {
        return Colors.oklch(l, c, h, alpha);
    }
}
