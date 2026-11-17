// The window switcher (WindowSwitcher.qml): Alt+Tab goes through the windows
// of every workspace and screen, the most recently focused first, so a quick
// Alt+Tab goes back to the window before; Alt+` through those of the focused
// window's application, or, while switching, of the picked window's. Letting
// go of Alt focuses the picked window (compositor/shortcuts.lua); the screen
// moves to its workspace. The switcher shows only after a moment, so a quick
// switch does not flash it.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: switcher

    property bool open
    property bool shown
    // The screen it shows on, by name.
    property string screen
    property list<HyprlandToplevel> windows
    property int index
    readonly property HyprlandToplevel picked: open ? windows[index] ?? null : null
    // Whether only one application's windows are listed.
    property bool narrowed

    // The windows by when they were last focused.
    function recent(): list<HyprlandToplevel> {
        return Hyprland.toplevels.values
            .filter(t => (t.workspace?.id ?? 0) > 0 && t.lastIpcObject.mapped !== false)
            .sort((a, b) => (a.lastIpcObject.focusHistoryID ?? 1e6) - (b.lastIpcObject.focusHistoryID ?? 1e6));
    }

    // Goes to the next window (1) or the one before (-1); with app, among
    // those of one application.
    function step(by: int, app: bool) {
        if (Lock.locked)
            return;
        if (!open) {
            const all = recent();
            const focused = Hyprland.activeToplevel;
            const cls = focused?.lastIpcObject.class;
            windows = app ? all.filter(t => t.lastIpcObject.class === cls) : all;
            narrowed = app;
            if (windows.length < 2) {
                windows = [];
                return;
            }
            index = by > 0 ? 1 : windows.length - 1;
            screen = Hyprland.focusedMonitor?.name ?? "";
            open = true;
            showing.restart();
            return;
        }
        if (app && !narrowed) {
            const cls = picked?.lastIpcObject.class;
            const keep = picked;
            windows = windows.filter(t => t.lastIpcObject.class === cls);
            index = windows.indexOf(keep);
            narrowed = true;
        }
        index = (index + by + windows.length) % windows.length;
    }

    function pick(at: int) {
        index = at;
        done();
    }

    // Focuses the picked window, which shows its workspace, once the
    // switcher has let go of the keyboard.
    function done() {
        if (!open)
            return;
        focusing.address = picked?.address ?? "";
        close();
        if (focusing.address)
            focusing.restart();
    }

    // Closes the picked window and keeps switching among the others.
    function closePicked() {
        if (!picked)
            return;
        Compositor.closeWindow(picked.address);
        const left = windows.filter(w => w !== picked);
        windows = left;
        index = Math.min(index, left.length - 1);
        if (left.length === 0)
            close();
    }

    function close() {
        showing.stop();
        open = false;
        shown = false;
        narrowed = false;
        windows = [];
    }

    Timer {
        id: focusing

        property string address

        interval: 50
        onTriggered: Compositor.focusWindow(address)
    }

    Timer {
        id: showing
        interval: 150
        onTriggered: switcher.shown = true
    }
}
