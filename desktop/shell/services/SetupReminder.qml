// Once, the first time the computer is online after Welcome closed without
// having been (Settings.setupPending): a notification that the browser and
// apps are still to choose. Opening it opens Welcome, online at the browser
// step; dismissing it ends it.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: reminder

    readonly property bool waiting: Settings.setupPending && Settings.welcomeOn === ""

    Timer {
        interval: 10000
        repeat: true
        triggeredOnStart: true
        running: reminder.waiting
        onTriggered: check.running = true
    }

    Process {
        id: check

        command: Connectivity.onlineQuery
        stdout: StdioCollector {
            onStreamFinished: {
                if (!reminder.waiting || !Connectivity.online(text))
                    return;
                Settings.setupPending = false;
                Notifications.post("Welcome", "system-software-install", "Finish setting up",
                    "Now that you're online, choose a browser and apps.", () => Settings.welcome());
            }
        }
    }
}
