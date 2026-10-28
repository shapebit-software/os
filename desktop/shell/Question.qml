// The questions applications ask through the portal (Portal.qml) that the
// person answers (QuestionDialog.qml): whether an application may do
// something, such as use the camera, with the choices it offers; which
// application opens a file or a link; and whether to share their name and
// picture, let an application go on in the background, add a launcher to
// Apps, or set a picture as the wallpaper. They wait their turn, the oldest
// shown.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: question

    // The questions, oldest first, each the socket that asked and the
    // request: its kind ("access", "open-with", "account", "background",
    // "launcher", or "wallpaper"), an icon, a title, a subtitle, a body, the
    // grant and deny labels, and what the kind needs: the choices, the
    // applications and the last one chosen, a picture, or a name.
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
        show(waiting.concat([{ socket: socket, request: request }]));
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
        Portal.answer(waiting[0].socket, answer);
        show(waiting.slice(1));
    }

    function show(next: var) {
        if (next.length && next[0] !== waiting[0])
            screen = Hyprland.focusedMonitor?.name ?? "";
        waiting = next;
    }

    function dropped(socket: Socket) {
        if (waiting.some(w => w.socket === socket))
            show(waiting.filter(w => w.socket !== socket));
    }
}
