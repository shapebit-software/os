// The map of one workspace in the strip (Strip.qml): its windows where they are on the
// screen, each with its application's icon.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

Item {
    id: map

    required property HyprlandWorkspace modelData
    required property ShellScreen screen
    required property HyprlandMonitor monitor
    // A click went to this workspace or one of its windows.
    signal activated

    readonly property bool current: modelData.active
    // The space between cells on the map.
    readonly property int cellGap: 4
    // The area the tiles cover on the screen, grown by half the gap between
    // tiles on every side, so the tiles cover it without gaps.
    readonly property var reserved: monitor?.lastIpcObject.reserved ?? [0, 0, 0, 0]
    readonly property real areaX: screen.x + reserved[0] + Theme.gap / 2
    readonly property real areaY: screen.y + reserved[1] + Theme.gap / 2
    readonly property real areaWidth: screen.width - reserved[0] - reserved[2] - Theme.gap
    readonly property real areaHeight: screen.height - reserved[1] - reserved[3] - Theme.gap

    width: 84
    height: Theme.stripHeight

    layer.enabled: hover.hovered
    layer.effect: MultiEffect { brightness: 0.12 }

    TapHandler {
        onTapped: {
            Compositor.focusWorkspace(map.modelData.id);
            map.activated();
        }
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    // An empty workspace is one plain cell.
    Rectangle {
        visible: map.modelData.toplevels.values.length === 0
        anchors.fill: parent
        color: map.current ? Qt.rgba(0.89, 0.9, 0.92, 0.4) : Qt.rgba(0.6, 0.62, 0.65, 0.28)
    }

    // The cells, laid out on an area grown by half the cell gap on every
    // side, then shrunk by as much, so cells meet the map's edges.
    Item {
        x: -map.cellGap / 2
        y: -map.cellGap / 2
        width: map.width + map.cellGap
        height: map.height + map.cellGap

        Repeater {
            model: map.modelData.toplevels

            Rectangle {
                id: cell

                required property HyprlandToplevel modelData

                // The compositor reports a new window's place a moment later.
                readonly property var ipc: modelData.lastIpcObject
                readonly property list<real> at: ipc.at ?? [0, 0]
                readonly property list<real> size: ipc.size ?? [0, 0]
                readonly property real sx: parent.width / map.areaWidth
                readonly property real sy: parent.height / map.areaHeight
                // Looked up again when the applications change, since the
                // first lookup can come before they are read.
                readonly property DesktopEntry entry: {
                    void DesktopEntries.applications.values;
                    return ipc.class ? DesktopEntries.heuristicLookup(ipc.class) : null;
                }

                visible: ipc.at !== undefined
                x: (at[0] - Theme.gap / 2 - map.areaX) * sx + map.cellGap / 2
                y: (at[1] - Theme.gap / 2 - map.areaY) * sy + map.cellGap / 2
                width: Math.max(2, (size[0] + Theme.gap) * sx - map.cellGap)
                height: Math.max(2, (size[1] + Theme.gap) * sy - map.cellGap)
                color: !map.current ? Qt.rgba(0.6, 0.62, 0.65, 0.55)
                    : modelData.activated ? Qt.rgba(0.98, 0.99, 1, 0.98)
                    : Qt.rgba(0.77, 0.79, 0.83, 0.8)

                IconImage {
                    readonly property int size: Math.min(cell.width, cell.height) >= 30 ? 22 : 14

                    anchors.centerIn: parent
                    implicitSize: size
                    visible: cell.entry !== null && size < Math.min(cell.width, cell.height)
                    source: Quickshell.iconPath(cell.entry?.icon ?? "", true)
                    opacity: map.current ? 1 : 0.5
                }

                TapHandler {
                    onTapped: {
                        Compositor.focusWindow(cell.modelData.address);
                        map.activated();
                    }
                }
            }
        }
    }
}
