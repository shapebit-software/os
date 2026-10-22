// The colors, the fonts, and the sizes that every part of the shell shares.
pragma Singleton
import QtQuick

QtObject {
    readonly property string font: "Instrument Sans"
    readonly property string mono: "JetBrains Mono"
    readonly property color text: "#e6e8eb"
    // The accent, and a pale tint of it for what is selected on light panels.
    readonly property color accent: oklch(0.52, 0.11, Settings.accentHueShown)
    readonly property color accentSoft: oklch(0.94, 0.03, Settings.accentHueShown)
    // The bars' fill (Settings.barBackground): glass, which the compositor
    // blurs what shows through, a solid color, or nothing, with a shadow
    // under what is on them instead.
    readonly property color barFill: Settings.barBackground === "Solid" ? "#1c1826"
        : Settings.barBackground === "Glass" ? Qt.rgba(0.047, 0.047, 0.094, 0.5) : "transparent"
    readonly property bool barShadow: Settings.barBackground === "None"
    // Popovers, the panels that open from the bars, as in the demo: light
    // glass from top to bottom with a thin ring, text in a dark violet, and
    // a violet veil for tiles, fields, and what is under the pointer.
    readonly property color popoverTop: oklch(0.985, 0.008, 285, 0.95)
    readonly property color popoverBottom: oklch(0.965, 0.012, 285, 0.93)
    readonly property color popoverRing: oklch(0.25, 0.04, 285, 0.14)
    readonly property color ink: oklch(0.27, 0.06, 290)
    readonly property color inkSoft: oklch(0.38, 0.07, 290)
    readonly property color inkFaint: oklch(0.48, 0.07, 290)
    function veil(alpha: real): color {
        return oklch(0.25, 0.04, 285, alpha);
    }
    // Warnings, such as muted devices: lines, and areas behind light text.
    readonly property color danger: "#f05653"
    readonly property color dangerFill: "#b63132"
    // The space between tiles, and between tiles and the screen edges; the
    // shell sets the compositor's to the same (Settings.qml).
    readonly property int gap: Settings.gapSize
    readonly property int barHeight: 40
    // The height of the workspace strip at the bottom of the screen.
    readonly property int stripHeight: 60
    // Rounded window corners round the shell's tiles too: tabs, the cells of
    // the maps, and the applications in Apps.
    readonly property bool rounded: Settings.windowCorners === "Rounded"

    // A color from OKLCH, as the demo writes them: lightness and chroma, 0
    // to 1 and 0 to about 0.4, hue in degrees, and opacity, 1 if left out.
    function oklch(l: real, c: real, h: real, alpha: real): color {
        const a = c * Math.cos(h * Math.PI / 180), b = c * Math.sin(h * Math.PI / 180);
        const l_ = Math.pow(l + 0.3963377774 * a + 0.2158037573 * b, 3);
        const m_ = Math.pow(l - 0.1055613458 * a - 0.0638541728 * b, 3);
        const s_ = Math.pow(l - 0.0894841775 * a - 1.2914855480 * b, 3);
        const gamma = x => {
            x = Math.min(1, Math.max(0, x));
            return x <= 0.0031308 ? 12.92 * x : 1.055 * Math.pow(x, 1 / 2.4) - 0.055;
        };
        return Qt.rgba(gamma(4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_),
            gamma(-1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_),
            gamma(-0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_),
            isNaN(alpha) ? 1 : alpha);
    }
}
