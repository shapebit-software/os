"""The system's colors (image/rootfs/usr/share/colors/colors.toml): the QML
module's values are generated from them and up to date, what cannot read them
keeps copies that match, the parts that use QML name no color of their own,
and the accent reads where it is used."""

import ast
import importlib.util
import math
import pathlib
import re

import pytest

ROOT = pathlib.Path(__file__).parents[2]

spec = importlib.util.spec_from_file_location("colors", ROOT / "scripts/colors.py")
colors = importlib.util.module_from_spec(spec)
spec.loader.exec_module(colors)

TABLE = colors.load()
NAMED = colors.colors(TABLE)
ACCENTS = TABLE["accents"]
PRESETS = list(ACCENTS["presets"])


def read(path):
    return (ROOT / path).read_text()


def accent_ink(l, c, h):
    """Colors.accentInk: lighter, with chroma as high as the screen allows."""
    lightness = ACCENTS["ink"]
    while c > 0 and not all(-0.0001 <= x <= 1.0001 for x in colors.linear(lightness, c, h)):
        c -= 0.005
    return colors.oklch(lightness, max(0, c), h)


def contrast(one, other):
    """The WCAG contrast ratio of two "#rrggbb" colors."""
    def luminance(color):
        rgb = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
        rgb = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in rgb]
        return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
    high, low = sorted([luminance(one), luminance(other)], reverse=True)
    return (high + 0.05) / (low + 0.05)


def test_qml_values_are_generated_from_the_colors():
    assert colors.main(["--check"]) == 0, "run `make colors`"


def test_roles_name_colors_that_exist():
    for surface, roles in TABLE["roles"].items():
        for role, value in roles.items():
            name = value if isinstance(value, str) else value["color"]
            assert name in NAMED, f"{surface}.{role}: {name}"


def test_no_name_reads_as_a_signal_handler():
    # In QML, `onAccent: "#fff"` sets no property: it is the handler of a
    # signal `accent`, so the role stayed black in the shell.
    names = [*NAMED, *(role for roles in TABLE["roles"].values() for role in roles)]
    assert not [name for name in names if re.match(r"on[A-Z]", name)]


def test_roles_are_the_ones_qml_declares():
    declared = set(re.findall(r"property color (\w+)", read("image/rootfs/usr/lib64/qt6/qml/Colors/Roles.qml")))
    for surface, roles in TABLE["roles"].items():
        assert set(roles) <= declared, surface


def test_default_accent_is_the_brand_violet():
    assert ACCENTS["default"] == "Violet"
    assert colors.oklch(*ACCENTS["presets"]["Violet"]) == NAMED["violet"] == "#5b2fd6"


def test_shell_defaults_to_the_default_accent():
    assert f'property string accent: "{ACCENTS["default"]}"' in read("desktop/shell/services/Settings.qml")


def test_portal_computes_colors_as_the_generator_does():
    # The portal reads the accents from the colors at run time, and computes
    # the accent from OKLCH in a copy of the same function.
    tree = ast.parse(read("desktop/portal/portal"))
    function = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "oklch")
    scope = {"math": math}
    exec(compile(ast.Module([function], []), "portal", "exec"), scope)
    for values in [*ACCENTS["presets"].values(), [*ACCENTS["custom"], 25]]:
        rgb = scope["oklch"](*values)
        assert "#" + "".join(f"{round(255 * x):02x}" for x in rgb) == colors.oklch(*values)


def test_boot_splash_has_the_colors():
    splash = dict(re.findall(r"^(\w+)=0x([0-9a-f]{6})$",
                             read("image/rootfs/usr/share/plymouth/themes/boot/boot.plymouth"), re.M))
    assert "#" + splash["BackgroundStartColor"] == NAMED["night"]
    assert "#" + splash["BackgroundEndColor"] == NAMED["night"]
    assert "#" + splash["ProgressBarBackgroundColor"] == NAMED["nightTrack"]
    assert "#" + splash["ProgressBarForegroundColor"] == NAMED["grey0"]


def test_console_background_is_night():
    kargs = read("image/rootfs/usr/lib/bootc/kargs.d/30-splash.toml")
    channels = {name: re.search(rf"vt\.default_{name}=0x([0-9a-f]{{2}})", kargs)[1] for name in ("red", "grn", "blu")}
    assert "#" + channels["red"] + channels["grn"] + channels["blu"] == NAMED["night"]


def test_compositor_has_the_colors():
    compositor = read("desktop/compositor/hyprland.lua")
    assert f'background_color         = "rgb({NAMED["night"][1:]})"' in compositor
    edge = f'"rgba({NAMED["windowEdge"][1:]}7a)"'
    assert f"active_border = {edge}, inactive_border = {edge}" in compositor


@pytest.mark.parametrize("name", PRESETS)
def test_light_text_reads_on_each_accent(name):
    assert contrast(colors.oklch(*ACCENTS["presets"][name]), NAMED["grey0"]) >= 4.5


@pytest.mark.parametrize("name", PRESETS)
def test_accent_text_reads_on_night(name):
    assert contrast(accent_ink(*ACCENTS["presets"][name]), NAMED["night"]) >= 4.5


@pytest.mark.parametrize("hue", range(0, 360, 15))
def test_accent_text_reads_on_night_for_every_custom_hue(hue):
    assert contrast(accent_ink(*ACCENTS["custom"], hue), NAMED["night"]) >= 4.5


# Every QML file that takes its colors from Colors, by way of its Theme.qml.
THEMED = [*sorted((ROOT / "desktop/shell").rglob("*.qml")),
          *sorted((ROOT / "image/rootfs/usr/share/sddm/themes/login").glob("*.qml")),
          *sorted((ROOT / "installer/ui/qml").glob("*.qml"))]
# Artwork, whose colors are its own: the wallpapers.
ARTWORK = ["desktop/shell/wallpaper/"]
# A color written out: hex, rgba, OKLCH with numbers, or a named color.
LITERAL = re.compile(r'"#[0-9a-fA-F]{3,8}"|Qt\.(rgba|hsla|hsva)\(|oklch\(\s*[\d.]|"(white|black|red|green|blue|gray|grey)"')


def test_qml_names_no_color_of_its_own():
    found = [f"{path.relative_to(ROOT)}:{number}: {line.strip()}"
             for path in THEMED if not any(str(path.relative_to(ROOT)).startswith(a) for a in ARTWORK)
             for number, line in enumerate(path.read_text().splitlines(), 1)
             if LITERAL.search(line) and not line.lstrip().startswith("//")]
    assert not found, "Take colors from Theme, which takes them from Colors:\n" + "\n".join(found)
