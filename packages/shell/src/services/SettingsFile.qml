import QtQuick
import Quickshell
import Quickshell.Io

// Settings kept in ~/.config/desktop/NAME.json: the shell's (Settings.qml),
// or a feature's, in its own file. Its child, a JsonAdapter, holds them, each
// a property with its default. Edits to the file take effect at once, and
// changes to the adapter are saved.
FileView {
    // The file's name, without .json: "settings" for the shell's, or the
    // feature's name.
    required property string name
    // Not Settings.directory: Settings is made of one of these.
    readonly property string directory: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/desktop"

    path: directory + "/" + name + ".json"
    blockLoading: true
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    // The first save needs the directory.
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", directory])
}
