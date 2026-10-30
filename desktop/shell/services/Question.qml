// The questions the person answers (QuestionDialog.qml), from applications
// through the portal (Portal.qml): whether an application may do something,
// such as use the camera, with the choices it offers; which application opens
// a file or a link; and whether to share their name and picture, let an
// application go on in the background, add a launcher to Apps, or set a
// picture as the wallpaper. And from the connection agent (Connectivity.qml):
// a network's password, and a Bluetooth device's pairing code. They wait
// their turn, the oldest shown.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: question

    // The questions, oldest first, each who asked, such as the portal's
    // socket, what answers them, and the request: its kind ("access",
    // "open-with", "account", "background", "launcher", "wallpaper",
    // "secret", or "pairing"), an icon, a title, a subtitle, a body, the grant
    // and deny labels, and what the kind needs: the choices, the applications
    // and the last one chosen, a picture, text fields (an id, a label, a value,
    // whether secret or read only), or a code to compare.
    property var waiting: []
    readonly property var request: waiting.length ? waiting[0].request : null
    // The screen the shown one is on: the focused one when it shows.
    property string screen

    function ask(socket: Socket, request: var) {
        // A wallpaper without a preview is set at once.
        if (request.kind === "wallpaper" && !request.preview) {
            Settings.wallpaperImage = request.image;
            Settings.wallpaper = "Image";
            Portal.answer(socket, { granted: true });
            return;
        }
        askFor(socket, request, answer => Portal.answer(socket, answer));
    }

    // Asks for `asker`; `reply` gets the answer.
    function askFor(asker: var, request: var, reply: var) {
        show(waiting.concat([{ asker: asker, request: request, reply: reply }]));
    }

    // Answers the shown question: granted, with what the kind needs, such as
    // the choices or the application; refused; or dismissed.
    function grant(answer: var) {
        const request = waiting[0]?.request;
        if (request?.kind === "wallpaper") {
            Settings.wallpaperImage = request.image;
            Settings.wallpaper = "Image";
        } else if (request?.kind === "account") {
            answer = { id: Account.user, name: Account.displayName, image: Account.picture ? Account.facePath : "" };
        }
        send(Object.assign({ granted: true }, answer));
    }

    function refuse() {
        send({ granted: false });
    }

    function dismiss() {
        send({ dismissed: true });
    }

    function send(answer: var) {
        if (!waiting.length)
            return;
        waiting[0].reply(answer);
        show(waiting.slice(1));
    }

    function show(next: var) {
        if (next.length && next[0] !== waiting[0])
            screen = Hyprland.focusedMonitor?.name ?? "";
        waiting = next;
    }

    // Withdraws what `asker` asked, such as when the portal's socket closes.
    function dropped(asker: var) {
        if (waiting.some(w => w.asker === asker))
            show(waiting.filter(w => w.asker !== asker));
    }
}
