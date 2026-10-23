// The share picker (SharePicker.qml), over everything, with the screens
// dimmed behind it, as the file chooser: the screens, then the windows, each
// as a picture of it with its name. A click selects; a double click, Enter,
// or Share shares it; Escape cancels.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: window

    required property ShellScreen modelData

    readonly property var request: SharePicker.request
    readonly property bool picking: request !== null && SharePicker.screen === (modelData?.name ?? "")
    // What is selected: "screen:NAME" or "window:ID", as the portal names it.
    property string selected

    // The windows the portal offers, with Hyprland's for their pictures.
    readonly property list<var> windows: (request?.windows ?? []).map(w => ({
        id: w.id,
        title: w.title || w.class,
        app: w.class,
        toplevel: Hyprland.toplevels.values.find(t => t.address.replace(/^0x/, "") === String(w.address).replace(/^0x/, ""))?.wayland ?? null,
    }))

    visible: request !== null
    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "share-picker"
    WlrLayershell.keyboardFocus: picking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    onPickingChanged: {
        if (picking) {
            selected = `screen:${modelData.name}`;
            body.forceActiveFocus();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.05, 0.04, 0.09, 0.45)
    }

    PopoverFrame {
        visible: window.picking
        anchors.centerIn: parent
        padding: 0

        Item {
            id: body

            width: Math.min(760, window.width - 80)
            height: Math.min(columns.implicitHeight + footer.height, window.height - 80)
            focus: true

            Keys.onEscapePressed: SharePicker.cancel()
            Keys.onReturnPressed: SharePicker.share(window.selected)
            Keys.onEnterPressed: SharePicker.share(window.selected)

            Flickable {
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: footer.top }
                contentHeight: columns.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: columns

                    width: parent.width
                    padding: 20
                    spacing: 12

                    Text {
                        text: "Share your screen"
                        color: Theme.ink
                        font { family: Theme.font; pixelSize: 15; weight: Font.DemiBold }
                    }

                    Heading { text: "Screens" }
                    Flow {
                        width: parent.width - 40
                        spacing: 10

                        Repeater {
                            model: Quickshell.screens

                            Tile {
                                required property ShellScreen modelData

                                key: `screen:${modelData?.name ?? ""}`
                                name: modelData?.name ?? ""
                                source: modelData
                            }
                        }
                    }

                    Heading {
                        visible: window.windows.length > 0
                        text: "Windows"
                    }
                    Flow {
                        width: parent.width - 40
                        spacing: 10

                        Repeater {
                            model: window.windows

                            Tile {
                                required property var modelData

                                key: `window:${modelData.id}`
                                name: modelData.title
                                detail: modelData.app
                                source: modelData.toplevel
                            }
                        }
                    }
                }
            }

            Item {
                id: footer

                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 60

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.veil(0.08)
                }

                Row {
                    anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    spacing: 4

                    Button {
                        text: "Cancel"
                        onActivated: SharePicker.cancel()
                    }
                    Button {
                        text: "Share"
                        strong: true
                        onActivated: SharePicker.share(window.selected)
                    }
                }
            }
        }
    }

    component Heading: Text {
        color: Theme.inkFaint
        font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
    }

    // A screen or a window: its picture, taken once, and its name.
    component Tile: Rectangle {
        id: tile

        property string key
        property string name
        property string detail
        property var source
        readonly property bool chosen: window.selected === key

        width: 164
        height: 132
        color: chosen ? Theme.accentSoft : Theme.veil(tileHover.hovered ? 0.06 : 0.03)
        border.color: chosen ? Theme.accent : "transparent"
        border.width: 2

        Rectangle {
            x: 8
            y: 8
            width: parent.width - 16
            height: 86
            color: Theme.veil(0.08)

            ScreencopyView {
                anchors.fill: parent
                anchors.margins: 1
                captureSource: window.picking ? tile.source : null
                live: false
            }
        }
        Column {
            x: 10
            y: 100
            width: parent.width - 20

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: tile.name
                color: Theme.ink
                font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
            }
            Text {
                visible: tile.detail !== ""
                width: parent.width
                elide: Text.ElideRight
                text: tile.detail
                color: Theme.inkFaint
                font { family: Theme.font; pixelSize: 10 }
            }
        }

        TapHandler {
            onTapped: {
                window.selected = tile.key;
                if (tapCount === 2)
                    SharePicker.share(tile.key);
            }
        }
        HoverHandler {
            id: tileHover
            cursorShape: Qt.PointingHandCursor
        }
    }

    // As the file chooser's: filled with the accent for the action itself.
    component Button: Rectangle {
        id: button

        property alias text: label.text
        property bool strong
        signal activated

        width: Math.max(96, label.width + 32)
        height: 34
        color: strong ? Theme.accent : Theme.veil(buttonHover.hovered ? 0.1 : 0.05)

        Text {
            id: label
            anchors.centerIn: parent
            color: button.strong ? "white" : Theme.ink
            font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
        }

        TapHandler {
            onTapped: button.activated()
        }
        HoverHandler {
            id: buttonHover
            cursorShape: Qt.PointingHandCursor
        }
    }
}
