// Who is signed in, on which computer, running which system.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: account

    readonly property string user: Quickshell.env("USER") ?? ""
    property string fullName
    readonly property string displayName: fullName || user
    readonly property string hostname: hostnameFile.text().trim()
    // Such as "ShapeBit OS 0.9", from /etc/os-release.
    readonly property string system: {
        const line = osRelease.text().split("\n").find(l => l.startsWith("PRETTY_NAME="));
        return line ? line.slice("PRETTY_NAME=".length).replace(/^"|"$/g, "") : "";
    }

    // The full name is the first field of the account's comment.
    Process {
        command: ["getent", "passwd", account.user]
        running: account.user !== ""
        stdout: StdioCollector {
            onStreamFinished: account.fullName = (text.split(":")[4] ?? "").split(",")[0]
        }
    }
    FileView {
        id: hostnameFile
        path: "/etc/hostname"
    }
    FileView {
        id: osRelease
        path: "/etc/os-release"
    }
}
