// The system's colors for QML: the shell, the login screen, and the installer
// import this module, and each one's Theme.qml picks its roles from here. The
// values (ColorValues.qml) are generated from /usr/share/colors/colors.toml,
// which says what each is for; this adds what needs computing: the accent,
// from the person's choice, and colors from OKLCH.
pragma Singleton
import QtQuick

ColorValues {
    // An accent's lightness, chroma, and hue: a preset by name, or "Custom"
    // with its hue. An unknown name, such as a preset since removed, is the
    // default.
    function accentValues(name: string, hue: real): var {
        return name === "Custom" ? [customAccent[0], customAccent[1], hue]
            : accents[name] ?? accents[defaultAccent];
    }
    // The accent: fills, such as buttons and switches, with light text on them.
    function accent(name: string, hue: real): color {
        const v = accentValues(name, hue);
        return oklch(v[0], v[1], v[2]);
    }
    // A pale tint of it, for what is selected on light surfaces.
    function accentSoft(name: string, hue: real): color {
        return oklch(softAccent[0], softAccent[1], accentValues(name, hue)[2]);
    }
    // The accent as text on dark surfaces: lighter, so it reads on night. The
    // chroma shrinks only as far as the screen's colors need.
    function accentInk(name: string, hue: real): color {
        const v = accentValues(name, hue);
        let c = v[1];
        while (c > 0 && !inGamut(inkAccentLightness, c, v[2]))
            c -= 0.005;
        return oklch(inkAccentLightness, Math.max(0, c), v[2]);
    }

    // A color from OKLCH: lightness and chroma, 0 to 1 and 0 to about 0.4,
    // hue in degrees, and opacity, 1 if left out. scripts/colors.py and the
    // portal compute the same in Python.
    function oklch(l: real, c: real, h: real, alpha: real): color {
        const rgb = linear(l, c, h).map(x => {
            x = Math.min(1, Math.max(0, x));
            return x <= 0.0031308 ? 12.92 * x : 1.055 * Math.pow(x, 1 / 2.4) - 0.055;
        });
        return Qt.rgba(rgb[0], rgb[1], rgb[2], isNaN(alpha) ? 1 : alpha);
    }
    function inGamut(l: real, c: real, h: real): bool {
        return linear(l, c, h).every(x => x >= -0.0001 && x <= 1.0001);
    }
    // OKLCH as linear sRGB, which may fall outside 0 to 1.
    function linear(l: real, c: real, h: real): var {
        const a = c * Math.cos(h * Math.PI / 180), b = c * Math.sin(h * Math.PI / 180);
        const l_ = Math.pow(l + 0.3963377774 * a + 0.2158037573 * b, 3);
        const m_ = Math.pow(l - 0.1055613458 * a - 0.0638541728 * b, 3);
        const s_ = Math.pow(l - 0.0894841775 * a - 1.2914855480 * b, 3);
        return [4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
            -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
            -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_];
    }
}
