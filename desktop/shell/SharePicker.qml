// The share picker: when an application shares the screen, Hyprland's portal
// asks what to share (session/share-picker), through the portal
// (Portal.qml), and the person picks it in the capture overlay
// (CaptureOverlay.qml), as for a screenshot: an area they draw, a window, or
// a whole screen. One question is open at a time; another, meanwhile, is
// turned away. What is shared is the portal's stream in PipeWire, linked to
// the applications that show it.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: picker

    // The open question: the windows that can be shared, each with the
    // portal's id, its class, title, and address.
    property var request: null
    readonly property bool asking: request !== null
    property Socket asker: null

    // The portal's streams, one for each thing shared, and the names of the
    // applications they go to.
    readonly property list<PwNode> streams: Pipewire.nodes.values
        .filter(n => n.type === PwNodeType.VideoSource && n.name.startsWith("xdph-streaming-"))
    readonly property bool sharing: streams.length > 0
    readonly property list<string> viewers: [...new Set(Pipewire.linkGroups.values
        .filter(g => g.target && streams.includes(g.source))
        .map(g => g.target.properties["application.name"] || g.target.description || g.target.name))]

    // Shares what was picked on a screen, as the overlay's mode names it: an
    // area, in the screen's coordinates; a window, by its address; or the
    // screen. With Settings.shareRemember, the application may share it
    // again without asking.
    function share(screen: ShellScreen, mode: string, area: rect, address: string) {
        let selection = `screen:${screen.name}`;
        if (mode === "Area") {
            selection = `region:${screen.name}@${Math.round(area.x)},${Math.round(area.y)},`
                + `${Math.round(area.width)},${Math.round(area.height)}`;
        } else if (mode === "Window") {
            const plain = a => String(a).replace(/^0x/, "");
            const offered = (request?.windows ?? []).find(w => plain(w.address) === plain(address));
            if (!offered)
                return;
            selection = `window:${offered.id}`;
        }
        send({ selection: selection, remember: Settings.shareRemember });
    }

    function cancel() {
        send({});
    }

    function send(answer: var) {
        if (asker)
            Portal.answer(asker, answer);
        asker = null;
        request = null;
        Capture.close();
    }

    // The overlay opens on the focused screen, unless it is open already.
    function ask(socket: Socket, question: var) {
        const screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        if (asking || Capture.stage || !screen) {
            Portal.answer(socket, {});
            return;
        }
        asker = socket;
        request = question;
        Capture.begin(screen);
    }

    function dropped(socket: Socket) {
        if (socket === asker) {
            asker = null;
            request = null;
            Capture.close();
        }
    }
}
