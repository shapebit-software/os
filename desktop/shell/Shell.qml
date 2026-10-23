// How the shell is arranged, and which panel is open. There are two bars
// (ShellBar.qml): the system bar, with the clock and the status buttons, and
// the dock, with Apps, the workspaces, and the quick actions. Each sits on an
// edge of the screen and has three zones, start, center, and end, holding
// items in order; Settings keeps where they are, and Settings > Shell
// changes it (ShellEditor.qml).
//
// A button that opens a panel tells where it is on the screen, and the panel
// opens beside it, off the bar (Popout.qml). One panel is open at a time.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: shell

    readonly property list<string> edges: ["Top", "Bottom", "Left", "Right"]
    readonly property list<string> zoneNames: ["start", "center", "end"]
    // The items, by id, with their names.
    readonly property var items: ({
        clock: "Clock",
        notifications: "Notifications",
        microphone: "Microphone",
        sound: "Sound",
        brightness: "Brightness",
        network: "Network",
        battery: "Battery",
        language: "Input language",
        account: "System menu",
        apps: "Apps",
        workspaces: "Workspaces",
        quick: "Quick actions",
    })

    // The open panel: "notifications", "microphone", "sound", "brightness",
    // "network", "battery", "language",
    // "account", "apps", "capture", "assistant", "layout", or none; the
    // screen it is open on, by name; the place of what opened it on that
    // screen; and the edge and depth of the bar it opens from.
    property string panel
    property string panelScreen
    property rect anchor
    property string edge: "Bottom"
    property real depth
    // The workspace whose layout menu is open, by id.
    property int workspace

    // Every bar window, for panels to keep open while one is clicked, so its
    // buttons can switch panels.
    property list<QtObject> bars

    function edgeOf(bar: string): string {
        return bar === "system" ? Settings.systemBar : Settings.dock;
    }

    // Moves a bar to an edge; a bar there takes the other's place.
    function place(bar: string, edge: string) {
        const other = bar === "system" ? "dock" : "system";
        if (edgeOf(other) === edge) {
            if (other === "system")
                Settings.systemBar = edgeOf(bar);
            else
                Settings.dock = edgeOf(bar);
        }
        if (bar === "system")
            Settings.systemBar = edge;
        else
            Settings.dock = edge;
    }

    // Moves an item to a bar's zone, before another item there, or last;
    // with no bar, off the bars, among the hidden items. The system menu,
    // the way to Settings, always stays on a bar.
    function move(item: string, bar: string, zone: string, before: string) {
        if (!bar && !canHide(item))
            return;
        const zones = JSON.parse(JSON.stringify(Settings.zones));
        for (const b of ["system", "dock"])
            for (const z of zoneNames)
                zones[b][z] = zones[b][z].filter(i => i !== item);
        const list = bar ? zones[bar][zone] : Settings.hiddenItems.filter(i => i !== item);
        const at = before ? list.indexOf(before) : -1;
        list.splice(at < 0 ? list.length : at, 0, item);
        Settings.hiddenItems = bar ? Settings.hiddenItems.filter(i => i !== item) : list;
        Settings.zones = zones;
    }

    function canHide(item: string): bool {
        return item !== "account";
    }

    function toggle(name: string, screen: string, anchor: rect, edge: string, depth: real) {
        if (panel === name && panelScreen === screen) {
            close();
            return;
        }
        shell.anchor = anchor;
        shell.edge = edge;
        shell.depth = depth;
        panelScreen = screen;
        panel = name;
    }

    function isOpen(name: string, screen: string): bool {
        return panel === name && panelScreen === screen;
    }

    function close() {
        panel = "";
    }
}
