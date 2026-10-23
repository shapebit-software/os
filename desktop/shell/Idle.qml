// What happens while the computer is idle or asleep, carried out by hypridle:
// the lock screen locks after the idle time in Settings, and before the
// computer sleeps, which waits for it; the screens turn off after their own
// idle time and come back on with input or after sleep. The shell writes
// hypridle's configuration from Settings and runs it again when they change.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: idle

    // hypridle's configuration file: one for each shell, in the runtime
    // directory, which goes with the session.
    readonly property string path: `${Quickshell.env("XDG_RUNTIME_DIR")}/desktop/idle-${Quickshell.processId}.conf`
    // hypridle reaches this shell, by its process, through its IPC (Lock.qml);
    // not through loginctl lock-session, which in development would lock the
    // developer's own session.
    readonly property string lockCommand: `qs ipc --pid ${Quickshell.processId} call lock lock`
    readonly property string screensOn: `hyprctl dispatch 'hl.dsp.dpms("on")'`
    readonly property string config: [
        "general {",
        `    lock_cmd = ${lockCommand}`,
        `    before_sleep_cmd = ${lockCommand}`,
        `    after_sleep_cmd = ${screensOn}`,
        // Sleep waits until the screen is locked.
        "    inhibit_sleep = 3",
        "}",
        ...Settings.lockAfter > 0 ? [
            "listener {",
            `    timeout = ${Settings.lockAfter}`,
            `    on-timeout = ${lockCommand}`,
            "}",
        ] : [],
        ...Settings.screenOffAfter > 0 ? [
            "listener {",
            `    timeout = ${Settings.screenOffAfter}`,
            `    on-timeout = hyprctl dispatch 'hl.dsp.dpms("off")'`,
            `    on-resume = ${screensOn}`,
            "}",
        ] : [],
    ].join("\n") + "\n"

    onConfigChanged: {
        hypridle.running = false;
        hypridle.running = true;
    }

    Process {
        id: hypridle

        command: ["sh", "-c", 'mkdir -p "${1%/*}" && printf %s "$2" >"$1" && exec hypridle --quiet --config "$1"',
            "sh", idle.path, idle.config]
        running: true
    }
}
