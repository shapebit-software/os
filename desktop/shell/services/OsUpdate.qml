// System updates, which the OS image's os-update downloads and stages in the
// background: the running system's version, and the state that os-update
// writes to /run/os-update/status.json: "checking", "current", "skipped" (a
// metered connection), "ready" with the version staged, or "failed". A new
// version, once ready, is announced once; the next restart or shutdown
// installs it. Check now (Settings > Updates) starts os-update@now.service,
// which the image's polkit rule lets the person at the computer start.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: update

    // The running build, such as "20261030_e0920a", or "dev".
    readonly property string version: {
        const line = osRelease.text().split("\n").find(l => l.startsWith("IMAGE_VERSION="));
        return line ? line.slice("IMAGE_VERSION=".length).replace(/^"|"$/g, "") : "";
    }
    readonly property var status: {
        try {
            return JSON.parse(statusFile.text() || "{}");
        } catch (e) {
            return {};
        }
    }
    readonly property string state: status.state ?? ""
    readonly property bool ready: state === "ready"
    readonly property bool checking: state === "checking" || starter.running

    // A version as people read it: "30 October 2026 · e0920a".
    function describe(version: string): string {
        const match = /^(\d{4})(\d{2})(\d{2})_([0-9a-f]+)$/.exec(version);
        if (!match)
            return version;
        const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
        const pattern = Settings.regionShown === "US" ? "MMMM d, yyyy" : "d MMMM yyyy";
        return `${Qt.formatDate(date, pattern)} · ${match[4]}`;
    }

    // What Settings > Updates says about the state.
    readonly property string stateText: {
        const checked = status.checked ? ` · checked ${Qt.formatDateTime(new Date(status.checked), Settings.timePattern)}` : "";
        switch (state) {
        case "checking":
            return "Checking for updates…";
        case "current":
            return "Up to date" + checked;
        case "skipped":
            return "Not checked on a metered connection" + checked;
        case "ready":
            return `${describe(status.version)} is ready · restart to install it`;
        case "failed":
            return `The last check failed: ${status.error || "unknown error"}`;
        default:
            return "Checks automatically every few hours";
        }
    }

    function checkNow() {
        starter.running = true;
    }

    // Announces a version once: Settings keeps the last one announced.
    onReadyChanged: {
        if (!ready || Settings.updateAnnounced === status.version)
            return;
        Settings.updateAnnounced = status.version;
        announcer.command = ["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
            "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify",
            "System update", "0", "system-software-update", "Update ready",
            `${describe(status.version)} installs when you restart or shut down.`, "[]", "{}", "0"];
        announcer.running = true;
    }

    Process {
        id: starter
        command: ["systemctl", "start", "--no-block", "os-update@now.service"]
    }
    Process {
        id: announcer
    }
    FileView {
        id: statusFile
        path: "/run/os-update/status.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }
    FileView {
        id: osRelease
        path: "/etc/os-release"
    }
}
