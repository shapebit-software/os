# Colors

The system's colors, and the QML module made from them: the package `shapebit-colors`.

Every color is named once, in
[colors.toml](colors.toml),
which the image installs, so the installer medium has it too. It holds the
brand's violet `#5b2fd6`, the default accent; night; ramps of greys, darks,
lavenders, inks, and reds; the accents to choose from; and the roles on light
and on dark surfaces. The person's choices, such as the accent, stay in the
shell's settings; the file holds the defaults and what there is to choose.

QML reads it through the module `Colors`
([Colors](Colors)),
in Qt's own folder of modules. Its values, `ColorValues.qml`, are generated
from the file by `make colors` and committed; `Colors.qml` adds what needs
computing, such as the accent from the person's choice. The shell, the login
screen, and the installer import it, and each one's `Theme.qml` picks the
roles it uses; nothing else names a color, apart from the wallpapers' artwork.
The accent fills controls under light text; on dark surfaces, text in the
accent uses a lighter version of it, `accentInk`.

The portal, which hands the accent to applications, reads the file when it
runs. What cannot read it keeps a copy that names the color there: the boot
splash, the console's colors in `kargs.d`, and the compositor.
`test_colors.py` checks that the generated values are current, the
copies, that no QML names a color of its own, and that text in the accent
reads on night. `make run` and `make lint` at the repository root and the installer's
tests take the module and the file from the source tree.
