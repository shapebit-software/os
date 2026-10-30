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
    // The account's picture, ~/.face as login screens read it, or empty;
    // with a counter, so pictures show a new one at the same path.
    readonly property string facePath: Quickshell.env("HOME") + "/.face"
    readonly property string picture: face.loaded ? `file://${facePath}?${pictureVersion}` : ""
    property int pictureVersion
    readonly property string hostname: hostnameFile.text().trim()
    // Such as "ShapeBit OS 0.9", from /etc/os-release.
    readonly property string system: {
        const line = osRelease.text().split("\n").find(l => l.startsWith("PRETTY_NAME="));
        return line ? line.slice("PRETTY_NAME=".length).replace(/^"|"$/g, "") : "";
    }

    // Makes a copy of an image the account's picture, also for the system's
    // account service where it accepts it.
    function setPicture(path: string) {
        setter.command = ["sh", "-c", 'cp -- "$1" "$2" && busctl call org.freedesktop.Accounts '
            + '"/org/freedesktop/Accounts/User$(id -u)" org.freedesktop.Accounts.User SetIconFile s "$2" '
            + '>/dev/null 2>&1; true', "sh", path, facePath];
        setter.running = true;
    }

    Process {
        id: setter
        onRunningChanged: {
            if (!running) {
                account.pictureVersion++;
                face.reload();
            }
        }
    }
    FileView {
        id: face
        path: account.facePath
        printErrors: false
        // Only whether it exists matters; the pictures read it themselves.
        watchChanges: true
        onFileChanged: {
            reload();
            account.pictureVersion++;
        }
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
