// What capture adds to the shell (packages/shell/src/services/Feature.qml),
// which its package installs as the shell's features/capture.qml, with its QML
// as the module qs.capture beside it: the capture overlay, which also picks
// what to share; its button on the bars and in the hot corner; Print; the
// portals' screenshots and screen sharing; and banners held back while the
// screen is shared.
import QtQuick
import Quickshell
import qs.capture
import qs.services

Feature {
    readonly property string icon: "M2.5 5.5v-3h3M10.5 2.5h3v3M13.5 10.5v3h-3M5.5 13.5h-3v-3M5.8 8a2.2 2.2 0 1 0 4.4 0a2.2 2.2 0 1 0-4.4 0z"

    // The overlay on the screen named, unless it is open already.
    function begin(name: string) {
        const screen = Quickshell.screens.find(s => s.name === name);
        if (screen && !Capture.stage)
            Capture.begin(screen);
    }

    // Print opens the overlay for a screenshot; with Alt, on the focused
    // window; with Super, on the whole screen; with Shift, for a recording of
    // the kind last chosen, the screen to begin with, or stops the one going on.
    function shortcut(name: string, screen: string) {
        if (name === "capture-record" && Capture.recording) {
            Capture.stop();
            return;
        }
        if (Capture.stage)
            return;
        if (name !== "capture-record")
            Capture.kind = "Shot";
        else if (!Capture.record)
            Capture.kind = "Screen";
        if (name === "capture-window")
            Capture.mode = "Window";
        else if (name === "capture-screen")
            Capture.mode = "Screen";
        begin(screen);
    }

    name: "capture"
    surfaces: [overlay]
    shortcuts: ({
        "capture": screen => shortcut("capture", screen),
        "capture-window": screen => shortcut("capture-window", screen),
        "capture-screen": screen => shortcut("capture-screen", screen),
        "capture-record": screen => shortcut("capture-record", screen),
    })
    items: ({ capture: { label: "Capture", icon: icon, component: barButton } })
    actions: [{ name: "capture", icon: icon, order: 2, tap: screen => begin(screen) }]
    recording: Capture.recording ? { elapsed: Capture.elapsed, stop: () => Capture.stop() } : null
    quiet: SharePicker.sharing
    portals: ({ screenshot: Capture, screencast: SharePicker })

    property Component overlay: Component { CaptureOverlay {} }
    property Component barButton: Component { CaptureBarButton {} }
}
