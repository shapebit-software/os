// The map of one workspace in the strip (Strip.qml): its windows where they
// are on the screen, each with its application's icon. Under the pointer, a
// button above the map opens the layout menu.
//
// Maps take drops (Dragging.qml). An application from Apps or a window from a
// map lands in a cell: on a window's cell it takes that window's place, which
// moves after the others; elsewhere it goes after the others. Meanwhile, maps
// whose layout has a picture show where the windows would be with one more,
// and the free cell. The layout button drags the workspace, which takes the
// place of the one it is dropped on.
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
    // A click or a drop went to this workspace or one of its windows.
    signal activated

    readonly property bool current: modelData.active
    readonly property list<HyprlandToplevel> windows: modelData.toplevels.values
    // The space between cells on the map.
    readonly property int cellGap: 4
    // The area the tiles cover on the screen, grown by half the gap between
    // tiles on every side, so the tiles cover it without gaps.
    readonly property var reserved: monitor?.lastIpcObject.reserved ?? [0, 0, 0, 0]
    readonly property real areaX: screen.x + reserved[0] + Theme.gap / 2
    readonly property real areaY: screen.y + reserved[1] + Theme.gap / 2
    readonly property real areaWidth: screen.width - reserved[0] - reserved[2] - Theme.gap
    readonly property real areaHeight: screen.height - reserved[1] - reserved[3] - Theme.gap

    // While an application or a window is dragged: where the windows would
    // be with one more, the last place being the free cell.
    readonly property list<rect> preview: Dragging.tile
        ? Layouts.place(Compositor.layoutOf(modelData.id), windows.length + 1, areaWidth, areaHeight) : []
    readonly property list<HyprlandToplevel> order: preview.length ? ordered() : []

    // Where a window is on the area.
    function placeOf(window: HyprlandToplevel): rect {
        const ipc = window.lastIpcObject;
        const at = ipc.at ?? [0, 0];
        const size = ipc.size ?? [0, 0];
        return Qt.rect(at[0] - Theme.gap / 2 - areaX, at[1] - Theme.gap / 2 - areaY,
            size[0] + Theme.gap, size[1] + Theme.gap);
    }

    // The windows in the order they fill the layout's cells, told by the cell
    // each one is in; any other window, such as a floating one, comes last.
    function ordered(): list<HyprlandToplevel> {
        const cells = Layouts.place(Compositor.layoutOf(modelData.id), windows.length, areaWidth, areaHeight);
        const placed = [], rest = [];
        for (const window of windows) {
            const r = placeOf(window);
            const x = r.x + r.width / 2, y = r.y + r.height / 2;
            const i = cells.findIndex((c, k) => !placed[k] && x >= c.x && x < c.x + c.width && y >= c.y && y < c.y + c.height);
            if (i >= 0)
                placed[i] = window;
            else
                rest.push(window);
        }
        return windows.map((_, k) => placed[k] ?? rest.shift());
    }

    function dropTile(target: HyprlandToplevel) {
        const app = Dragging.app, window = Dragging.window;
        Dragging.clear();
        if (app) {
            Compositor.launch(app, modelData.id, target?.address ?? "");
            activated();
        } else if (window && window !== target) {
            const here = window.workspace === modelData;
            if (!here)
                Compositor.moveWindow(window.address, modelData.id);
            if (target) {
                Compositor.swapWindows(window.address, target.address);
            } else if (here) {
                // Past each window after it.
                const order = ordered();
                for (const other of order.slice(order.indexOf(window) + 1))
                    Compositor.swapWindows(window.address, other.address);
            }
        }
    }

    width: 84
    height: Theme.stripHeight
    opacity: Dragging.workspace === modelData.id ? 0.4 : 1

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

    // Drops on the map outside its cells.
    DropArea {
        id: mapDrop

        readonly property bool active: Dragging.tile || Dragging.workspace > 0 && Dragging.workspace !== map.modelData.id

        anchors.fill: parent
        onEntered: drag => drag.accepted = active
        onDropped: {
            if (Dragging.tile) {
                map.dropTile(null);
            } else {
                Compositor.moveWorkspace(Dragging.workspace, map.modelData.id);
                Dragging.clear();
            }
        }
    }

    // The picture, brighter under the pointer.
    Item {
        anchors.fill: parent
        layer.enabled: hover.hovered
        layer.effect: MultiEffect { brightness: 0.12 }

        // An empty workspace is one plain cell.
        Rectangle {
            visible: map.windows.length === 0 && !map.preview.length
            anchors.fill: parent
            color: map.current ? Qt.rgba(0.89, 0.9, 0.92, 0.4) : Qt.rgba(0.6, 0.62, 0.65, 0.28)
        }

        // The cells, laid out on an area grown by half the cell gap on every
        // side, then shrunk by as much, so cells meet the map's edges.
        Item {
            id: cells

            readonly property real sx: width / map.areaWidth
            readonly property real sy: height / map.areaHeight

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
                    readonly property int rank: map.order.indexOf(modelData)
                    readonly property rect area: map.preview[rank] ?? map.placeOf(modelData)
                    // Looked up again when the applications change, since the
                    // first lookup can come before they are read.
                    readonly property DesktopEntry entry: {
                        void DesktopEntries.applications.values;
                        return ipc.class ? DesktopEntries.heuristicLookup(ipc.class) : null;
                    }
                    readonly property string iconSource: Quickshell.iconPath(entry?.icon ?? "", true)

                    visible: ipc.at !== undefined
                    x: area.x * cells.sx + map.cellGap / 2
                    y: area.y * cells.sy + map.cellGap / 2
                    width: Math.max(2, area.width * cells.sx - map.cellGap)
                    height: Math.max(2, area.height * cells.sy - map.cellGap)
                    opacity: Dragging.window === modelData ? 0.35 : 1
                    color: !map.current ? Qt.rgba(0.6, 0.62, 0.65, 0.55)
                        : modelData.activated ? Qt.rgba(0.98, 0.99, 1, 0.98)
                        : Qt.rgba(0.77, 0.79, 0.83, 0.8)

                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.MoveAction
                    Drag.imageSource: iconSource
                    Drag.imageSourceSize: Qt.size(32, 32)
                    Drag.onDragFinished: Dragging.clear()

                    IconImage {
                        readonly property int size: Math.min(cell.width, cell.height) >= 30 ? 22 : 14

                        anchors.centerIn: parent
                        implicitSize: size
                        visible: cell.entry !== null && size < Math.min(cell.width, cell.height)
                        source: cell.iconSource
                        opacity: map.current ? 1 : 0.5
                    }

                    // The place a drop would take.
                    Rectangle {
                        visible: cellDrop.containsDrag
                        anchors.fill: parent
                        anchors.margins: -2
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.accent
                    }

                    TapHandler {
                        onTapped: {
                            Compositor.focusWindow(cell.modelData.address);
                            map.activated();
                        }
                    }
                    DragHandler {
                        target: null
                        onActiveChanged: {
                            if (active) {
                                Dragging.window = cell.modelData;
                                cell.Drag.active = true;
                            }
                        }
                    }
                    DropArea {
                        id: cellDrop

                        anchors.fill: parent
                        enabled: Dragging.tile && Dragging.window !== cell.modelData
                        onDropped: map.dropTile(cell.modelData)
                    }
                }
            }

            // The free cell.
            Rectangle {
                readonly property rect area: map.preview[map.preview.length - 1] ?? Qt.rect(0, 0, 0, 0)

                visible: map.preview.length > 0
                x: area.x * cells.sx + map.cellGap / 2
                y: area.y * cells.sy + map.cellGap / 2
                width: Math.max(2, area.width * cells.sx - map.cellGap)
                height: Math.max(2, area.height * cells.sy - map.cellGap)
                color: map.current ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.6, 0.62, 0.65, 0.14)
                border.width: freeDrop.containsDrag ? 2 : 1
                border.color: freeDrop.containsDrag ? Theme.accent : Qt.rgba(1, 1, 1, map.current ? 0.45 : 0.26)

                DropArea {
                    id: freeDrop

                    anchors.fill: parent
                    onDropped: map.dropTile(null)
                }
            }
        }
    }

    // The workspace a drop would go to.
    Rectangle {
        visible: mapDrop.containsDrag
        anchors.fill: parent
        anchors.margins: -5
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
    }

    // The layout button, showing the workspace's layout; dragging it drags
    // the workspace.
    Rectangle {
        id: layoutButton

        visible: hover.hovered || buttonHover.hovered || menu.visible
        anchors.horizontalCenter: parent.horizontalCenter
        y: -10
        width: 32
        height: 18
        radius: 9
        color: buttonHover.hovered ? "#2c3240" : "#1c2029"
        border.color: Qt.rgba(1, 1, 1, 0.45)

        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.MoveAction
        Drag.onDragFinished: Dragging.clear()

        Icon {
            anchors.centerIn: parent
            height: 12
            gridWidth: 12
            gridHeight: 12
            strokeWidth: 1.1
            color: "#f6f9fb"
            strokes: "M1 1h10v10H1z" + Layouts.byId(Compositor.layoutOf(map.modelData.id)).icon
        }

        TapHandler {
            // Takes the click from the map below.
            gesturePolicy: TapHandler.WithinBounds
            onTapped: menu.visible ? menu.visible = false : menu.open()
        }
        HoverHandler {
            id: buttonHover
            cursorShape: Qt.PointingHandCursor
            // The picture under the pointer while dragging is the map; it is
            // taken now, since taking it is not instant.
            onHoveredChanged: {
                if (hovered)
                    map.grabToImage(result => layoutButton.Drag.imageSource = result.url);
            }
        }
        DragHandler {
            target: null
            onActiveChanged: {
                if (active) {
                    menu.visible = false;
                    Dragging.workspace = map.modelData.id;
                    layoutButton.Drag.active = true;
                }
            }
        }
    }

    LayoutMenu {
        id: menu
        map: map
        workspace: map.modelData.id
        screenWidth: map.screen.width
    }
}
