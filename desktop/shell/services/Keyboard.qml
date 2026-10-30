// The keyboard layouts of the session and the active one, from the
// compositor, which has them from Settings (Language > Keyboards).
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
    // The active layout's language, such as "EN" for "us", as the bar shows it.
    readonly property string code: active < layouts.length ? languageOf(layouts[active]) : ""
    // Layout names and languages by code, such as "English (US)" and "en",
    // from the xkb rules.
    property var names: ({})
    property var languages: ({})

    function nameOf(layout: string): string {
        return names[layout] ?? layout;
    }

    function languageOf(layout: string): string {
        return (languages[layout] ?? layout).toUpperCase();
    }

    // How the letter keys are arranged, for the layouts of Latin script.
    function arrangementOf(layout: string): string {
        if (["de", "at", "ch", "cz", "sk", "hu", "si", "hr", "ba"].includes(layout))
            return "QWERTZ";
        if (["fr", "be"].includes(layout))
            return "AZERTY";
        if (["ru", "ua", "by", "bg", "mk", "gr", "il", "ara", "ir", "jp", "kr", "cn", "th", "in", "am", "ge"].includes(layout))
            return "";
        return "QWERTY";
    }

    // Reads the layouts again, after Settings changed them.
    function refresh() {
        devices.running = true;
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
        path: "/usr/share/X11/xkb/rules/evdev.xml"
        onLoaded: {
            // Each layout: <layout><configItem><name>, maybe a comment,
            // <shortDescription> (the language), and <description>.
            const pattern = /<layout>\s*<configItem>\s*<name>([^<]+)<\/name>\s*(?:<!--.*?-->\s*)?<shortDescription>([^<]+)<\/shortDescription>\s*<description>([^<]+)<\/description>/g;
            const names = {}, languages = {};
            const xml = text();
            for (let match = pattern.exec(xml); match; match = pattern.exec(xml)) {
                names[match[1]] = match[3];
                languages[match[1]] = match[2];
            }
            keyboard.names = names;
            keyboard.languages = languages;
        }
    }
}
