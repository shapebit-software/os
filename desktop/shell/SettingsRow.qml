// One setting in Settings: its label and detail, and its control, at the
// right or, for pictures and the shell's layout, below them.
//
// A row is { label, detail, kind } and what its kind needs:
//   value       { value, open() if it leads to a page }
//   choice      { options, selected, select(value) }; options as in SettingsChoice
//   select      { options, selected, select(value) }; options as [label, value]
//   toggle      { on, toggle() }
//   picture     { open() }: the account's picture
//   swatches    the accent colors
//   wallpapers  { open() for a picture of one's own }
//   gaps        the space between windows
//   shell       the bars' layout (ShellEditor)
//   info        nothing beside the text
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

Item {
    id: row

    required property var modelData
    readonly property string kind: modelData.kind ?? "value"
    readonly property bool wide: ["swatches", "wallpapers", "shell"].includes(kind)

    implicitHeight: Math.max(56, (wide ? labels.height + below.height + 12 : Math.max(labels.height, control.height)) + 24)

    Column {
        id: labels

        x: 16
        y: row.wide ? 12 : (row.height - height) / 2
        width: row.width - 32 - (row.wide ? 0 : control.width + 16)
        spacing: 3

        Text {
            width: parent.width
            text: row.modelData.label ?? ""
            color: "#1d2022"
            font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: row.modelData.detail ?? ""
            color: "#5f6469"
            font { family: Theme.font; pixelSize: 12 }
        }
    }

    // The control at the right.
    Item {
        id: control

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        visible: !row.wide
        // As large as the control shown.
        width: Math.max(0, ...children.filter(c => c.visible).map(c => c.width))
        height: Math.max(0, ...children.filter(c => c.visible).map(c => c.height))

        // A value, with a chevron when it opens a page.
        Row {
            visible: row.kind === "value" || row.kind === "picture"
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: row.kind === "picture" ? "Change" : row.modelData.value ?? ""
                color: "#44484d"
                font { family: Theme.font; pixelSize: 12 }
            }
            Avatar {
                visible: row.kind === "picture"
                width: 44
                height: 44
            }
            Icon {
                visible: row.kind === "value" && row.modelData.open !== undefined
                anchors.verticalCenter: parent.verticalCenter
                height: 10
                gridWidth: 10
                gridHeight: 10
                strokeWidth: 1.3
                color: "#44484d"
                strokes: "M3.5 2l3 3-3 3"
            }

            TapHandler {
                enabled: row.modelData.open !== undefined
                onTapped: row.modelData.open()
            }
            HoverHandler {
                enabled: row.modelData.open !== undefined
                cursorShape: Qt.PointingHandCursor
            }
        }

        // Options; custom gaps also have steps smaller or larger.
        Row {
            visible: row.kind === "choice" || row.kind === "gaps"
            spacing: 10

            // Custom gaps: a step smaller or larger.
            Row {
                visible: row.kind === "gaps" && Settings.gaps === "Custom"
                height: 30

                component Step: Rectangle {
                    id: step

                    property string strokes
                    signal clicked

                    width: 26
                    height: 26
                    anchors.verticalCenter: parent.verticalCenter
                    color: stepHover.hovered ? "#e6e8ea" : "transparent"

                    Icon {
                        anchors.centerIn: parent
                        height: 10
                        gridWidth: 10
                        gridHeight: 10
                        strokeWidth: 1.4
                        color: "#44484d"
                        strokes: step.strokes
                    }
                    TapHandler {
                        onTapped: step.clicked()
                    }
                    HoverHandler {
                        id: stepHover
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                Step {
                    strokes: "M2 5h6"
                    onClicked: Settings.gapPixels = Math.max(0, Settings.gapPixels - 2)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    horizontalAlignment: Text.AlignHCenter
                    text: `${Settings.gapPixels} px`
                    color: "#1d2022"
                    font { family: Theme.mono; pixelSize: 11 }
                }
                Step {
                    strokes: "M2 5h6M5 2v6"
                    onClicked: Settings.gapPixels = Math.min(32, Settings.gapPixels + 2)
                }
            }
            SettingsChoice {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.kind === "choice" || row.kind === "gaps"
                options: row.kind === "gaps" ? [...Object.keys(Settings.gapSizes), "Custom"] : row.modelData.options ?? []
                selected: row.kind === "gaps" ? Settings.gaps : row.modelData.selected
                onPicked: value => row.kind === "gaps" ? Settings.gaps = value : row.modelData.select(value)
            }
        }

        SettingsSelect {
            visible: row.kind === "select"
            options: row.modelData.options ?? []
            selected: row.modelData.selected
            onPicked: value => row.modelData.select(value)
        }

        Switch {
            visible: row.kind === "toggle"
            on: row.modelData.on ?? false
            offColor: "#d5d8db"
            onToggled: row.modelData.toggle()
        }
    }

    // The control below the labels.
    Item {
        id: below

        x: 16
        y: labels.y + labels.height + 12
        visible: row.wide
        width: row.width - 32
        height: row.kind === "swatches" ? swatches.height
            : row.kind === "wallpapers" ? wallpapers.height
            : row.kind === "shell" ? shellEditor.height : 0

        // The accent colors, and a custom one with its hue.
        Row {
            id: swatches

            visible: row.kind === "swatches"
            x: 4
            topPadding: 4
            bottomPadding: 4
            spacing: 8

            component Swatch: Rectangle {
                id: swatch

                property bool current
                signal clicked

                width: 22
                height: 22
                radius: 11

                // The ring around the current color, a white space apart.
                Rectangle {
                    visible: swatch.current
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: 15
                    z: -1
                    color: "white"
                    border.width: 2
                    border.color: swatch.color
                }
                TapHandler {
                    onTapped: swatch.clicked()
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }

            Repeater {
                model: Object.keys(Settings.accents)

                Swatch {
                    required property string modelData

                    color: Theme.oklch(0.52, 0.11, Settings.accents[modelData])
                    current: Settings.accent === modelData
                    onClicked: Settings.accent = modelData
                }
            }
            Swatch {
                current: Settings.accent === "Custom"
                color: current ? Theme.accent : "white"
                border.color: current ? "transparent" : "#cfd3d6"
                onClicked: Settings.accent = "Custom"

                Icon {
                    anchors.centerIn: parent
                    height: 12
                    gridWidth: 12
                    gridHeight: 12
                    strokeWidth: 1.6
                    capStyle: ShapePath.RoundCap
                    color: parent.current ? "#fbfcfd" : "#6a6f74"
                    strokes: "M6 1.5v9M1.5 6h9"
                }
            }

            // The custom hue, along the colors of every hue.
            Item {
                visible: Settings.accent === "Custom"
                width: 130
                height: 22

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 6
                    width: 120
                    height: 8
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.oklch(0.52, 0.11, 0) }
                        GradientStop { position: 0.17; color: Theme.oklch(0.52, 0.11, 60) }
                        GradientStop { position: 0.33; color: Theme.oklch(0.52, 0.11, 120) }
                        GradientStop { position: 0.5; color: Theme.oklch(0.52, 0.11, 180) }
                        GradientStop { position: 0.67; color: Theme.oklch(0.52, 0.11, 240) }
                        GradientStop { position: 0.83; color: Theme.oklch(0.52, 0.11, 300) }
                        GradientStop { position: 1; color: Theme.oklch(0.52, 0.11, 359) }
                    }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 6 + Settings.accentHue / 359 * 120 - width / 2
                    width: 14
                    height: 14
                    radius: 7
                    color: Theme.accent
                    border.width: 2
                    border.color: "white"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function pick(x: real) {
                        Settings.accentHue = Math.round(Math.max(0, Math.min(1, (x - 6) / 120)) * 359);
                    }
                    onPressed: mouse => pick(mouse.x)
                    onPositionChanged: mouse => pick(mouse.x)
                }
            }
        }

        // The wallpapers, and a picture of one's own.
        Grid {
            id: wallpapers

            readonly property real tileWidth: (width - 2 * spacing) / 3

            visible: row.kind === "wallpapers"
            width: parent.width
            columns: 3
            spacing: 10

            Repeater {
                model: ["Dusk", "Slate", "Dune", "Fjord", "Moss", "Image"]

                Item {
                    id: tile

                    required property string modelData
                    readonly property bool current: Settings.wallpaper === modelData
                    readonly property bool own: modelData === "Image"

                    width: wallpapers.tileWidth
                    height: Math.round(width * 0.62)

                    Rectangle {
                        visible: tile.current
                        anchors.fill: parent
                        anchors.margins: -4
                        color: "white"
                        border.width: 2
                        border.color: Theme.accent
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "white"
                        border.color: "#cfd3d6"
                        visible: tile.own && !Settings.wallpaperImage
                    }
                    Backdrop {
                        anchors.fill: parent
                        visible: !tile.own || Settings.wallpaperImage !== ""
                        preset: tile.modelData
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: tile.own && !Settings.wallpaperImage
                        height: 12
                        gridWidth: 12
                        gridHeight: 12
                        strokeWidth: 1.4
                        color: "#6a6f74"
                        strokes: "M6 1.5v9M1.5 6h9"
                    }

                    TapHandler {
                        onTapped: tile.own ? row.modelData.open() : Settings.wallpaper = tile.modelData
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        ShellEditor {
            id: shellEditor
            visible: row.kind === "shell"
            width: parent.width
        }
    }
}
