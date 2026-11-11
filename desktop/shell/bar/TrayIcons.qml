// The background apps' icons on a bar (ShellItem.qml; Tray.qml): side by
// side, or stacked, each one on a card over the one before it, until the
// pointer is on them, when they spread out side by side. A click on an icon does what its
// application does for one, such as showing its window; a middle click, its
// second action; a right click opens its menu (TrayMenu.qml), as does a
// click where the menu is all the application has; the wheel is passed on.
// An icon that asks for attention has a dot. An icon the theme lacks shows
// as a plain application's, and a symbolic one takes the bar's text color.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.controls
import qs.services
import "../services/tray.js" as Logic

Item {
    id: tray

    // The ShellBar the icons are on.
    required property var bar
    property bool tile
    property int size: 30

    // Each icon's place along the bar, and the space between two places.
    readonly property int place: 24
    readonly property int spacing: 2
    readonly property string screenName: bar.modelData?.name ?? ""
    readonly property bool menuOpen: Shell.isOpen("tray", screenName)
    // Spread out: always side by side; stacked, under the pointer and while
    // a menu is open.
    readonly property bool open: !Tray.stacked || hover.hovered || menuOpen
    // How far apart the icons stand, which moves as they spread and stack.
    property real pitch: Logic.pitch(place, spacing, Tray.stacked, open)
    readonly property real length: Logic.length(Tray.items.length, place, pitch) + (tile ? 12 : 0)

    function showMenu(entry: SystemTrayItem, from: Item) {
        if (!entry.hasMenu)
            return;
        // Another icon's menu closes first; the same one's closes instead.
        if (menuOpen && Tray.menuOf !== entry)
            Shell.close();
        Tray.menuOf = entry;
        bar.open("tray", from);
    }

    implicitWidth: bar.vertical ? size : length
    implicitHeight: bar.vertical ? length : size

    Behavior on pitch {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    Glass {
        anchors.fill: parent
        visible: tray.tile
    }

    HoverHandler {
        id: hover
    }

    Repeater {
        // Keeps the icons that stay as others come and go.
        model: ScriptModel {
            values: Tray.items
        }

        Item {
            id: icon

            required property SystemTrayItem modelData
            required property int index
            readonly property real along: (tray.tile ? 6 : 0) + index * tray.pitch
            readonly property real across: (tray.size - tray.place) / 2
            readonly property string name: Logic.iconName(modelData.icon)
            readonly property bool current: tray.menuOpen && Tray.menuOf === modelData

            x: tray.bar.vertical ? across : along
            y: tray.bar.vertical ? along : across
            width: tray.place
            height: tray.place

            // Stacked, a card behind the icon, which covers the one below.
            Rectangle {
                anchors.fill: parent
                visible: Tray.stacked
                radius: Theme.rounded ? 2.5 : 0
                color: Theme.night
                border.color: Theme.sheen(0.22)
            }
            Rectangle {
                anchors.fill: parent
                visible: tray.open
                color: icon.current ? Theme.sheen(0.12) : Theme.shade(1)
                opacity: icon.current ? 1 : iconHover.hovered ? 0.14 : 0
            }
            IconImage {
                anchors.centerIn: parent
                implicitSize: 18
                source: icon.name ? Quickshell.iconPath(icon.name, "application-x-executable") : icon.modelData.icon
                layer.enabled: Logic.symbolic(icon.modelData.icon)
                layer.effect: MultiEffect {
                    brightness: 1
                    colorization: 1
                    colorizationColor: Theme.text
                }
            }
            Rectangle {
                x: parent.width - 8
                y: 2
                visible: Tray.needsAttention(icon.modelData)
                width: 6
                height: 6
                radius: 3
                color: Theme.accent
            }

            TapHandler {
                onTapped: {
                    if (icon.modelData.onlyMenu)
                        tray.showMenu(icon.modelData, icon);
                    else
                        icon.modelData.activate();
                }
            }
            TapHandler {
                acceptedButtons: Qt.MiddleButton
                onTapped: icon.modelData.secondaryActivate()
            }
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: tray.showMenu(icon.modelData, icon)
            }
            WheelHandler {
                orientation: Qt.Horizontal | Qt.Vertical
                onWheel: event => {
                    const horizontal = event.angleDelta.y === 0;
                    icon.modelData.scroll(horizontal ? event.angleDelta.x : event.angleDelta.y, horizontal);
                }
            }
            HoverHandler {
                id: iconHover
                cursorShape: Qt.PointingHandCursor
            }

            Tooltip {
                target: icon
                edge: tray.bar.edge
                hovered: iconHover.hovered && tray.open && !tray.menuOpen
                text: icon.modelData.tooltipTitle || icon.modelData.title
            }
        }
    }
}
