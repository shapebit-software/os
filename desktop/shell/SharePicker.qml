// The share picker: when an application shares the screen, Hyprland's portal
// asks which screen or window (session/share-picker), through the portal
// (Portal.qml), and the picker (SharePickerDialog.qml) answers. One question
// is open at a time; another, meanwhile, is turned away.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: picker

    // The open question: the windows that can be shared, each with the
    // portal's id, its class, title, and address.
    property var request: null
    readonly property bool asking: request !== null
    // The screen it shows on, by name: the focused one when asked.
    property string screen

    property Socket asker: null

    // Shares a screen, by name, or a window, by the portal's id.
    function share(selection: string) {
        send({ selection: selection });
    }

    function cancel() {
        send({});
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
        Hyprland.refreshToplevels();
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
}
