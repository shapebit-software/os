# Capture

Screenshots and recordings of the screen, the voice, and the camera: the
package `shapebit-capture`.

Its user interface is its own QML, the module `qs.capture`
([src/shell/](src/shell/)): the capture overlay, its button on the bars and in
the hot corner, and Print. The package installs it in the shell's folder, with
[feature.qml](src/feature.qml), which says what it adds to the shell
([Features](../shell/src/services/Feature.qml)). Its settings are kept in
`~/.config/desktop/capture.json`. `make lint` checks its QML against the
shell's modules.

The overlay's panel is one row of icons: a selection, a window, or the
screen; a switch between a screenshot and a recording, whose knob is the
capture button; and markup for screenshots, or a timer and the microphone for
recordings. Applications ask for screenshots, and what to share, through the
shell's portals (portal/src/portal and portal/src/share-picker); for sharing,
the panel has Share in place of the switch, and Remember, which lets the
application share it again without asking. While the screen is shared,
banners wait, and the capture button is filled with the accent.

[camera](src/camera) records the camera, and writes what it sees for the
overlay to show; [skip-silence](src/skip-silence) cuts the silences out of
voice and camera recordings.
