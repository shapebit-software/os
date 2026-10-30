// The window menu (Super+W; Shortcuts.qml), over the middle of the focused
// window: full screen; moving the window to another workspace of its screen,
// to a new one, or to another screen; the workspace's layout, among those
// that suit its number of windows; and closing it. The arrows go through
// the rows, left and right change the layout, and Enter does what the row
// says.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland

BarPanel {
    id: menu

    // The window, as it was when the menu opened.
    property HyprlandToplevel target
    readonly property HyprlandWorkspace workspace: target?.workspace ?? null
    readonly property var others: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor === workspace?.monitor && w.toplevels.values.length > 0)
        .sort((a, b) => a.id - b.id)
    readonly property var layouts: {
        const count = workspace?.toplevels.values.length ?? 0;
        const current = Compositor.layoutOf(workspace?.id ?? 0);
        return Layouts.all.filter(l => l.id === current || Layouts.suits(l.id, count));
    }
    readonly property string layout: Compositor.layoutOf(workspace?.id ?? 0)
    // The rows: { label, keys, act }, the layout's with change instead.
    readonly property var rows: {
        if (!target)
            return [];
        const address = target.address;
        const rows = [{
            label: target.lastIpcObject.fullscreen ? "End full screen" : "Full screen",
            keys: "Super+F",
            act: () => Compositor.toggleFullscreen(address),
        }];
        others.forEach((w, i) => {
            if (w !== workspace)
                rows.push({ label: `Move to workspace ${i + 1}`, keys: `Super+Shift+${i + 1}`,
                    act: () => Compositor.moveWindow(address, w.id) });
        });
        if (others.length < 8)
            rows.push({ label: "Move to a new workspace", keys: "",
                act: () => Compositor.moveWindow(address, Math.max(0, ...Hyprland.workspaces.values.map(w => w.id)) + 1) });
        for (const monitor of Hyprland.monitors.values)
            if (monitor !== workspace?.monitor)
                rows.push({ label: `Move to screen ${monitor.name}`, keys: "",
                    act: () => Compositor.moveWindowToScreen(address, monitor.name) });
        if (menu.layouts.length > 1)
            rows.push({ label: "Layout", keys: "", change: by => menu.changeLayout(by) });
        rows.push({ label: "Close", keys: "Super+Q", act: () => Compositor.closeWindow(address) });
        return rows;
    }
    property int current

    function changeLayout(by: int) {
        const at = layouts.findIndex(l => l.id === layout);
        const next = layouts[(at + by + layouts.length) % layouts.length];
        Compositor.setLayout(workspace.id, next.id);
    }

    function run(row: var) {
        if (row.change) {
            row.change(1);
            return;
        }
        dismissed();
        row.act();
    }

    name: "window"
    centered: true
    panelWidth: 280
    spacing: 0

    onVisibleChanged: {
        if (!visible)
            return;
        target = Hyprland.activeToplevel;
        current = 0;
        list.forceActiveFocus();
    }

    Column {
        id: list

        width: parent.width
        Keys.onPressed: event => {
            const row = menu.rows[menu.current];
            if (event.key === Qt.Key_Down)
                menu.current = (menu.current + 1) % menu.rows.length;
            else if (event.key === Qt.Key_Up)
                menu.current = (menu.current - 1 + menu.rows.length) % menu.rows.length;
            else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && row?.change)
                row.change(event.key === Qt.Key_Left ? -1 : 1);
            else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && row)
                menu.run(row);
            else if (event.key === Qt.Key_Escape)
                menu.dismissed();
            else
                return;
            event.accepted = true;
        }

        Repeater {
            model: menu.rows

            Rectangle {
                id: row

                required property var modelData
                required property int index

                width: list.width
                height: 32
                color: menu.current === index ? Theme.veil(0.08) : "transparent"

                Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label
                    color: Theme.ink
                    font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                }
                // The shortcut that does the same, or the layout between
                // arrows that change it.
                Text {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: row.modelData.change ? `‹  ${Layouts.all.find(l => l.id === menu.layout)?.name ?? ""}  ›` : row.modelData.keys
                    color: row.modelData.change ? Theme.ink : Theme.inkFaint
                    font { family: row.modelData.change ? Theme.font : Theme.mono; pixelSize: row.modelData.change ? 13 : 10 }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        if (hovered)
                            menu.current = row.index;
                    }
                }
                TapHandler {
                    onTapped: point => {
                        if (row.modelData.change)
                            row.modelData.change(point.position.x < row.width / 2 ? -1 : 1);
                        else
                            menu.run(row.modelData);
                    }
                }
            }
        }
    }
}
