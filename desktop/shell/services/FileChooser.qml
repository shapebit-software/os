// The file chooser: when an application opens or saves a file, the portal
// (Portal.qml) asks, and the picker (FileChooserDialog.qml) answers. One
// question is open at a time; another, meanwhile, is turned away.
pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: chooser

    readonly property string home: Quickshell.env("HOME")
    // The open question: whether to save, the title, the accept button's
    // label, whether several files or folders are chosen, the filters (a
    // name and file name patterns each) and the one picked, and the folder
    // and file name to start with.
    property var request: null
    readonly property bool asking: request !== null
    // The screen it shows on, by name: the focused one when asked.
    property string screen
    // The folder of the last answer, where the next question starts unless
    // the application names one.
    property string lastFolder: home
    // Home, then the person's folders (xdg-user-dirs), by path and name.
    property list<var> places: [{ path: home, name: "Home" }]

    property Socket asker: null

    function choose(paths: list<string>, filter: int) {
        if (paths.length)
            lastFolder = paths[0].substring(0, paths[0].lastIndexOf("/")) || "/";
        send({ paths: paths, filter: filter });
    }

    function cancel() {
        send({ paths: [] });
    }

    function send(answer: var) {
        if (asker)
            Portal.answer(asker, answer);
        asker = null;
        request = null;
    }

    function ask(socket: Socket, question: var) {
        if (asking) {
            Portal.answer(socket, {});
            return;
        }
        screen = Hyprland.focusedMonitor?.name ?? "";
        asker = socket;
        request = question;
    }

    function dropped(socket: Socket) {
        if (socket === asker) {
            asker = null;
            request = null;
        }
    }

    Process {
        command: ["sh", "-c", "for d in DESKTOP DOCUMENTS DOWNLOAD MUSIC PICTURES VIDEOS; do xdg-user-dir $d; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").filter(p => p && p !== chooser.home);
                chooser.places = [chooser.places[0]].concat(
                    [...new Set(found)].map(p => ({ path: p, name: p.split("/").pop() })));
            }
        }
    }
}
