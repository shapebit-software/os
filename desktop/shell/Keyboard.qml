// The keyboard layouts of the session and the active one, from the
// compositor. The layouts themselves are set in the compositor's input
// settings; this only switches between them.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: keyboard

    // Layout codes, such as "us" or "de".
    property list<string> layouts
    property int active
    readonly property string code: active < layouts.length ? layouts[active].toUpperCase() : ""
    // Layout names by code, such as "English (US)", from the xkb rules.
    property var names: ({})

    function nameOf(layout: string): string {
        return names[layout] ?? layout;
    }

    function select(index: int) {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(index)]);
    }

    Process {
        id: devices

        command: ["hyprctl", "devices", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const keyboards = JSON.parse(text).keyboards;
                const main = keyboards.find(k => k.main) ?? keyboards[0];
                if (!main)
                    return;
                keyboard.layouts = main.layout.split(",");
                keyboard.active = main.active_layout_index;
            }
        }
    }

    // The compositor reports layout switches and configuration reloads.
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            if (event.name === "activelayout" || event.name === "configreloaded")
                devices.running = true;
        }
    }

    FileView {
        path: "/usr/share/X11/xkb/rules/evdev.lst"
        onLoaded: {
            // The "! layout" section lists "  <code>  <name>" lines.
            const section = text().split("\n! ").find(s => s.startsWith("layout"));
            const names = {};
            for (const line of section?.split("\n").slice(1) ?? []) {
                const match = line.match(/^\s+(\S+)\s+(.+)$/);
                if (match)
                    names[match[1]] = match[2];
            }
            keyboard.names = names;
        }
    }
}
