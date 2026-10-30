// A bar of one screen (Shell.qml): the system bar, a band along its edge with
// the bar's fill behind its items, or the dock, which floats a gap off its
// edge with each item on glass of its own. Each of its zones holds its items
// in order: the start zone at the left or top, the center zone in the
// middle, the end zone at the right or bottom.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property ShellScreen modelData
    // "system" or "dock".
    required property string kind

    readonly property bool dock: kind === "dock"
    readonly property string edge: Shell.edgeOf(kind)
    readonly property bool vertical: edge === "Left" || edge === "Right"
    // The size of the items across the window.
    readonly property int size: dock ? Theme.stripHeight : 30
    // How far the bar reaches into the screen, where panels open.
    readonly property real depth: dock ? Theme.stripHeight + Theme.gap : Theme.barHeight
    // The dock's window reaches a gap past the bar toward the screen's
    // middle, for the maps' layout buttons.
    readonly property real reach: dock ? Theme.gap : 0

    // Opens a panel beside one of the bar's items.
    function open(panel: string, item: Item) {
        const at = item.mapToItem(null, 0, 0);
        const x = at.x + (edge === "Right" ? window.modelData.width - window.width : 0);
        const y = at.y + (edge === "Bottom" ? window.modelData.height - window.height : 0);
        Shell.toggle(panel, window.modelData.name, Qt.rect(x, y, item.width, item.height), edge, depth);
    }

    screen: modelData
    WlrLayershell.layer: WlrLayer.Top
    // The compositor blurs behind the system bar (compositor/hyprland.lua).
    WlrLayershell.namespace: dock ? "dock" : "bar"
    anchors {
        top: edge !== "Bottom"
        bottom: edge !== "Top"
        left: edge !== "Right"
        right: edge !== "Left"
    }
    implicitWidth: vertical ? depth + reach : 0
    implicitHeight: vertical ? 0 : depth + reach
    // The dock's tiles stop a gap off it; the compositor adds that gap.
    exclusiveZone: depth
    color: "transparent"
    // The dock takes input only on its items and the space toward the
    // screen's middle beside them; the rest of its band passes through.
    mask: Region {
        item: window.dock ? null : fill

        Region { item: window.dock ? zones : null }
        Region { item: window.dock ? reachArea : null }
    }

    Component.onCompleted: Shell.bars = [...Shell.bars, window]
    Component.onDestruction: Shell.bars = Shell.bars.filter(b => b !== window)

    // The system bar's fill: glass, which the compositor blurs, a solid
    // color, or none.
    Rectangle {
        id: fill
        anchors.fill: parent
        visible: !window.dock
        color: Theme.barFill
    }

    // A click on the bar but off its items closes the open panel; panels
    // stay open for clicks on the bars otherwise (Popout.qml).
    TapHandler {
        onTapped: point => {
            for (const zone of zones.children) {
                const at = zone.mapFromItem(null, point.position.x, point.position.y);
                if (zone.childAt?.(at.x, at.y))
                    return;
            }
            Shell.close();
        }
    }

    // The zones, a gap off the edge for the dock.
    Item {
        id: zones

        readonly property real inset: window.dock ? Theme.gap : (window.depth - window.size) / 2

        x: window.edge === "Right" ? window.width - inset - width : window.vertical ? inset : 0
        y: window.edge === "Bottom" ? window.height - inset - height : !window.vertical ? inset : 0
        width: window.vertical ? window.size : window.width
        height: window.vertical ? window.height : window.size

        Repeater {
            model: Shell.zoneNames

            GridLayout {
                id: zone

                required property string modelData
                readonly property real margin: window.dock ? Theme.gap : 10

                flow: window.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                rowSpacing: window.dock ? 4 : 2
                columnSpacing: window.dock ? 4 : 2
                x: window.vertical ? 0 : modelData === "start" ? margin
                    : modelData === "end" ? zones.width - margin - width : (zones.width - width) / 2
                y: !window.vertical ? 0 : modelData === "start" ? margin
                    : modelData === "end" ? zones.height - margin - height : (zones.height - height) / 2

                Repeater {
                    model: Settings.zones[window.kind]?.[zone.modelData] ?? []

                    ShellItem {
                        bar: window
                    }
                }
            }
        }
    }

    // The space toward the screen's middle along the dock.
    Item {
        id: reachArea
        x: window.edge === "Left" ? zones.x + zones.width : window.edge === "Right" ? zones.x - width : 0
        y: window.edge === "Top" ? zones.y + zones.height : window.edge === "Bottom" ? zones.y - height : 0
        width: window.vertical ? window.reach : window.width
        height: window.vertical ? window.height : window.reach
    }
}
