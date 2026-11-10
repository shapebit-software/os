// How the shell is arranged, and which panel is open. There are two bars
// (ShellBar.qml): the system bar, with the clock and the status buttons, and
// the dock, with Apps, the workspaces, and the quick actions. Each sits on an
// edge of the screen and has three zones, start, center, and end, holding
// items in order; on the dock, buttons can be half size, two to a slot.
// Settings keeps where they are, and Settings > Shell changes it
// (ShellEditor.qml), through the functions here over bars.js.
//
// A button that opens a panel tells where it is on the screen, and the panel
// opens beside it, off the bar (Popout.qml). One panel is open at a time.
pragma Singleton
import QtQuick
import Quickshell
import "bars.js" as Bars

Singleton {
    id: shell

    readonly property list<string> edges: ["Top", "Bottom", "Left", "Right"]
    readonly property list<string> zoneNames: Bars.zoneNames
    // The items, by id, with their names.
    readonly property var items: ({
        clock: "Clock",
        downloads: "Downloads",
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
        capture: "Capture",
        dictation: "Dictation",
        assistant: "Assistant",
    })

    // The open panel: "notifications", "microphone", "sound", "brightness",
    // "network", "battery", "language",
    // "account", "apps", "assistant", "layout", "window", or none; the
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

    // Moves an item to a bar's zone, at an index of that zone's items as
    // shown, or last for -1; with no bar, off the bars, among the hidden
    // items. The system menu, the way to Settings, always stays on a bar.
    function move(item: string, bar: string, zone: string, index: int) {
        if (!bar && !canHide(item))
            return;
        save(Bars.move(Settings.zones, Settings.hiddenItems, item, bar, zone, index));
    }

    // Moves an item one place earlier (-1) or later (1) on its bar, into
    // the next zone past its zone's edge.
    function step(item: string, delta: int) {
        const next = Bars.step(Settings.zones, Settings.hiddenItems, item, delta);
        if (next)
            save(next);
    }

    // Puts a hidden item back where it is by default, last in that zone.
    function show(item: string) {
        const home = Bars.home(Settings.defaultZones, item);
        move(item, home.bar, home.zone, -1);
    }

    function save(next: var) {
        Settings.hiddenItems = next.hidden;
        Settings.zones = next.zones;
    }

    // Where an item is: { bar, zone, index }, bar "" when hidden.
    function find(item: string): var {
        return Bars.find(Settings.zones, Settings.hiddenItems, item);
    }

    function canHide(item: string): bool {
        return item !== "account";
    }

    function canHalve(item: string): bool {
        return Bars.canHalve(item);
    }

    // Whether an item is half size: set so, a button, and on the dock.
    function isHalf(item: string): bool {
        return Settings.halfItems.includes(item) && Bars.canHalve(item)
            && find(item)?.bar === "dock";
    }

    function setHalf(item: string, half: bool) {
        Settings.halfItems = [...Settings.halfItems.filter(i => i !== item), ...(half ? [item] : [])];
    }

    // A zone's items in slots across the bar; half-size ones pair up on the
    // dock.
    function slots(bar: string, zone: string): var {
        return Bars.slots(Settings.zones[bar]?.[zone] ?? [], bar === "dock" ? Settings.halfItems : []);
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

    // A keyboard shortcut asks for a panel on a screen (Shortcuts.qml); the
    // item that opens it on that screen's bars opens it (ShellItem.qml).
    signal requested(name: string, screen: string)

    // Opens a panel as its item would, or closes it. With the item off the
    // bars, the panel opens from the middle of the system bar.
    function request(name: string, screen: string) {
        if (isOpen(name, screen)) {
            close();
            return;
        }
        requested(name, screen);
        const target = Quickshell.screens.find(s => s.name === screen);
        if (isOpen(name, screen) || !target)
            return;
        const edge = Settings.systemBar;
        const across = edge === "Top" || edge === "Bottom";
        toggle(name, screen, Qt.rect(across ? target.width / 2 : edge === "Left" ? 0 : target.width,
            across ? (edge === "Top" ? 0 : target.height) : target.height / 2, 0, 0), edge, Theme.barHeight);
    }

    function isOpen(name: string, screen: string): bool {
        return panel === name && panelScreen === screen;
    }

    function close() {
        panel = "";
    }
}
