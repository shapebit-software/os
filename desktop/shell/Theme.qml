// The colors, the fonts, and the sizes that every part of the shell shares.
pragma Singleton
import QtQuick

QtObject {
    readonly property string font: "Instrument Sans"
    readonly property string mono: "JetBrains Mono"
    readonly property color text: "#e6e8eb"
    readonly property color accent: Settings.accent === "Custom" ? oklch(0.52, 0.11, Settings.accentHue)
        : Settings.accents[Settings.accent] ?? "#007890"
    // The bars' fill (Settings.barBackground): glass, which the compositor
    // blurs what shows through, a solid color, or nothing, with a shadow
    // under what is on them instead.
    readonly property color barFill: Settings.barBackground === "Solid" ? "#1c1826"
        : Settings.barBackground === "Glass" ? Qt.rgba(0.047, 0.047, 0.094, 0.5) : "transparent"
    readonly property bool barShadow: Settings.barBackground === "None"
    // Panels: their body, edge (also of fields in them), and entries under
    // the pointer.
    readonly property color panel: Qt.rgba(0.153, 0.157, 0.188, 0.96)
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
    // Rounded window corners round the shell's tiles too: tabs, the cells of
    // the maps, and the applications in Apps.
    readonly property bool rounded: Settings.windowCorners === "Rounded"

    // A color from OKLCH, as the demo writes them: lightness and chroma, 0
    // to 1 and 0 to about 0.4, and hue in degrees.
    function oklch(l: real, c: real, h: real): color {
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
            gamma(-0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_));
    }
}
