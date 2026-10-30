// What the keyboard shortcuts ask of the shell (compositor/shortcuts.lua), on
// the focused screen: Apps, the notifications, Settings, the system menu,
// the window menu, the lock screen, the capture overlay, the sound and the
// media, the window switcher, and the list of shortcuts (ShortcutsWindow.qml).
// On the lock screen, only the sound and media keys work.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris

Singleton {
    id: shortcuts

    // Every shortcut, from the compositor: { mods: ["Super", "Ctrl", "Alt",
    // "Shift"], key, code, description }, with the key's name or its code.
    property var all: []
    // The screen the list of shortcuts is open on, by name.
    property string listOn

    readonly property string focused: Hyprland.focusedMonitor?.name ?? ""
    readonly property ShellScreen screen: Quickshell.screens.find(s => s.name === focused) ?? null
    // The player the media keys control: the one playing, or the first.
    readonly property MprisPlayer player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    function run(name: string) {
        const node = name === "mute-microphone" ? Audio.input : Audio.output;
        switch (name) {
        case "volume-up":
        case "volume-down":
            if (node?.audio) {
                node.audio.muted = false;
                node.audio.volume = Math.max(0, Math.min(1, node.audio.volume + (name === "volume-up" ? 0.05 : -0.05)));
            }
            return;
        case "mute":
        case "mute-microphone":
            if (node?.audio)
                node.audio.muted = !node.audio.muted;
            return;
        case "play":
            if (player?.canTogglePlaying)
                player.togglePlaying();
            return;
        case "next-track":
            if (player?.canGoNext)
                player.next();
            return;
        case "previous-track":
            if (player?.canGoPrevious)
                player.previous();
            return;
        }
        if (Lock.locked || !screen)
            return;
        switch (name) {
        case "apps":
            // Super is held to see its shortcuts in the list.
            if (!listOn)
                Shell.request("apps", focused);
            break;
        case "notifications":
            Shell.request("notifications", focused);
            break;
        case "system":
            Shell.request("account", focused);
            break;
        case "settings":
            if (Settings.openOn === focused)
                Settings.openOn = "";
            else
                Settings.open(focused, Settings.section);
            break;
        case "lock":
            Lock.lock();
            break;
        case "window-menu":
            openWindowMenu();
            break;
        case "help":
            listOn = listOn === focused ? "" : focused;
            if (listOn)
                Compositor.dispatch("function() shortcuts.report() end");
            break;
        case "capture":
        case "capture-window":
        case "capture-screen":
        case "capture-record":
            capture(name);
            break;
        case "switch-next":
        case "switch-previous":
        case "switch-app-next":
        case "switch-app-previous":
            Switcher.step(name.endsWith("next") ? 1 : -1, name.includes("app"));
            break;
        case "switch-done":
            Switcher.done();
            break;
        }
    }

    // Print opens the capture overlay as it was last; with Alt, on the
    // focused window; with Super, on the whole screen; with Shift, for a
    // recording, or stops the one going on.
    function capture(name: string) {
        if (name === "capture-record" && Capture.recording) {
            Capture.stop();
            return;
        }
        if (Capture.stage)
            return;
        Capture.record = name === "capture-record";
        if (name === "capture-window")
            Capture.mode = "Window";
        else if (name === "capture-screen")
            Capture.mode = "Screen";
        Capture.begin(screen);
    }

    // The window menu opens over the middle of the focused window.
    function openWindowMenu() {
        const window = Hyprland.activeToplevel;
        const ipc = window?.lastIpcObject;
        if (!ipc?.at || window.monitor?.name !== focused) {
            Shell.close();
            return;
        }
        Shell.toggle("window", focused, Qt.rect(ipc.at[0] - screen.x, ipc.at[1] - screen.y, ipc.size[0], ipc.size[1]),
            Settings.systemBar, 0);
    }

    Connections {
        target: Compositor

        function onShortcut(name: string) {
            shortcuts.run(name);
        }
    }

    // The keys as the compositor binds them, such as "SUPER + SHIFT + code:10".
    Connections {
        target: Compositor

        function onShortcutList(list: string) {
            const mods = { SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift" };
            shortcuts.all = list.split(";").map(entry => {
                const [keys, description] = entry.split("|");
                const parts = keys.split("+").map(p => p.trim());
                const key = parts.pop();
                return {
                    mods: ["Super", "Ctrl", "Alt", "Shift"].filter(m => parts.some(p => mods[p] === m)),
                    key: key.startsWith("code:") ? "" : key,
                    code: key.startsWith("code:") ? Number(key.slice(5)) : 0,
                    description,
                };
            });
        }
    }
}
