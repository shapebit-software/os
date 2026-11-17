// Copied text outlives the application it came from: clipman keeps the last
// copy and offers it again once that application closes. It keeps only that
// one, in the runtime directory, so nothing copied reaches the disk.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: clipboard

    // One for each shell, in the runtime directory, which goes with the
    // session.
    readonly property string path: `${Quickshell.env("XDG_RUNTIME_DIR")}/desktop/clipboard-${Quickshell.processId}.json`

    Process {
        // Those of shells that have ended go first, as for Idle.qml.
        command: ["sh", "-c", 'mkdir -p "${1%/*}" && for f in "${1%/*}"/clipboard-*.json; do p=${f##*-}; '
            + 'kill -0 "${p%.json}" 2>/dev/null || rm -f "$f"; done; '
            + 'exec wl-paste --type text --watch clipman store --max-items=1 --histpath="$1"', "sh", clipboard.path]
        running: true
    }
}
