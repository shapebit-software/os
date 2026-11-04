"""The default accent, Plum, is the same in the desktop shell, the portal that
hands it to applications, the installer, and the login screen."""

import math
import pathlib
import re

ROOT = pathlib.Path(__file__).parents[2]


def read(path):
    return (ROOT / path).read_text()


def oklch_hex(l, c, h):
    """An OKLCH color as sRGB hex, as shell/services/Theme.qml makes it."""
    a, b = c * math.cos(math.radians(h)), c * math.sin(math.radians(h))
    l_ = (l + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m_ = (l - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s_ = (l - 0.0894841775 * a - 1.2914855480 * b) ** 3

    def channel(x):
        x = min(1, max(0, x))
        x = 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055
        return round(255 * x)

    rgb = (4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
           -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
           -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_)
    return "#" + "".join(f"{channel(x):02x}" for x in rgb)


def test_shell_defaults_to_plum():
    settings = read("desktop/shell/services/Settings.qml")
    assert 'property string accent: "Plum"' in settings
    assert "accents[accent] ?? 335" in settings
    assert '"Plum": 335' in settings


def test_portal_defaults_to_plum():
    portal = read("desktop/portal/portal")
    assert 'chosen.get("accent", "Plum")' in portal
    assert "hues.get(accent, 335)" in portal


def test_installer_and_login_use_plum():
    plum = oklch_hex(0.52, 0.11, 335)
    for theme in ("installer/ui/qml/Theme.qml",
                  "image/rootfs/usr/share/sddm/themes/login/Theme.qml"):
        accent = re.search(r'property color accent: "(#[0-9a-f]{6})"', read(theme))
        assert accent and accent[1] == plum, theme
