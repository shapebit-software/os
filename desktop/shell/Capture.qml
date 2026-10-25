// Screenshots and screen recordings, through the capture overlay
// (CaptureOverlay.qml): the person picks an area they draw, a window, or a
// whole screen, then captures it; after the timer, if set, a recording
// starts, or the screenshot is saved to Pictures/Screenshots, or, with
// Settings.captureMarkup, first opens for markup, then is saved or copied.
// Recordings go to Videos/Recordings. Applications ask for screenshots through the
// portal (Portal.qml): the overlay then takes a screenshot only, and the
// application gets the file. Applications sharing the screen ask what to
// share the same way (SharePicker.qml), also while recording.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: capture

    // Recording ends at once for the person; wf-recorder may still be
    // finishing the file, and nothing else starts until it has.
    readonly property bool recording: recorder.running && !stopping
    property bool stopping
    property date startedAt
    // The recording's length so far, as m:ss.
    property string elapsed: "0:00"

    // The overlay's screen, and its stage: "select" while picking, "wait"
    // during the timer, "markup" with the screenshot, or none.
    property ShellScreen screen: null
    property string stage
    // What to pick: "Area", "Window", or "Screen"; whether to record; and
    // the timer for recordings, in seconds, 0 for none.
    property string mode: "Area"
    property bool record
    property int delay
    // The seconds left on the timer.
    property int countdown
    // The picked area, in the screen's coordinates; the last one drawn
    // shows again next time.
    property rect area
    property rect lastArea
    // A screenshot saved without markup, for the overlay to confirm.
    signal shot(path: string)
    // The screen as it was when captured, for markup.
    property string frozen

    // The portal's question, answered with the screenshot's file.
    property var request: null
    property Socket asker: null

    readonly property string runtime: `${Quickshell.env("XDG_RUNTIME_DIR")}/desktop`
    property string pictures: `${Quickshell.env("HOME")}/Pictures`
    property string videos: `${Quickshell.env("HOME")}/Videos`

    function begin(screen: ShellScreen) {
        if (stage || recorder.running && !SharePicker.asking)
            return;
        Hyprland.refreshToplevels();
        capture.screen = screen;
        stage = "select";
    }

    function take(area: rect) {
        capture.area = area;
        if (mode === "Area")
            lastArea = area;
        countdown = record ? delay : 0;
        stage = "wait";
        // The overlay leaves the screen before the capture, also with no timer.
        timer.interval = countdown ? 1000 : 150;
        timer.restart();
    }

    // The area on the whole desktop, as grim and wf-recorder take it.
    function geometry(): string {
        return `${screen.x + Math.round(area.x)},${screen.y + Math.round(area.y)} `
            + `${Math.round(area.width)}x${Math.round(area.height)}`;
    }

    function shoot() {
        if (record) {
            // Frames come steadily, not only when the screen changes, so the
            // recording ends as soon as it is stopped, and plays evenly.
            // With Settings.captureMicrophone, the default microphone too.
            recorder.command = ["sh", "-c", 'mkdir -p "$1" && exec wf-recorder --no-damage $3 -g "$2" -f "$1/Recording $(date \'+%F %H-%M-%S\').mp4"',
                "sh", `${videos}/Recordings`, geometry(), Settings.captureMicrophone ? "--audio" : ""];
            startedAt = new Date();
            elapsed = "0:00";
            recorder.running = true;
            close();
            return;
        }
        if (!Settings.captureMarkup) {
            const path = screenshotPath();
            saver.command = ["sh", "-c", 'mkdir -p "${1%/*}" && grim -g "$2" "$1" && echo "$1"', "sh", path, geometry()];
            saver.running = true;
            return;
        }
        // A new file each time, so the overlay does not show a cached one.
        const file = `${runtime}/capture-${Date.now()}.png`;
        grim.command = ["sh", "-c", 'mkdir -p "$4" && rm -f "$1"/capture-*.png && grim -o "$2" "$3" && echo "$3"',
            "sh", runtime, screen.name, file, `${pictures}/Screenshots`];
        grim.file = file;
        grim.running = true;
    }

    // Where a screenshot is saved: Pictures/Screenshots, by date and time.
    function screenshotPath(): string {
        return `${pictures}/Screenshots/Screenshot ${Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss")}.png`;
    }

    // The screenshot is saved, with markup or without.
    function saved(path: string) {
        if (asker)
            Portal.answer(asker, { path: path });
        asker = null;
        close();
    }

    function copied(path: string) {
        Quickshell.execDetached(["sh", "-c", 'exec wl-copy --type image/png <"$1"', "sh", path]);
        cancel();
    }

    function cancel() {
        if (asker)
            Portal.answer(asker, { path: "" });
        asker = null;
        if (SharePicker.asking)
            SharePicker.cancel();
        close();
    }

    function close() {
        timer.stop();
        stage = "";
        request = null;
    }

    function stop() {
        stopping = true;
        recorder.signal(2); // SIGINT: wf-recorder finishes the file.
    }

    function ask(socket: Socket, question: var) {
        const screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        if (stage || recorder.running || !screen) {
            Portal.answer(socket, {});
            return;
        }
        request = question;
        asker = socket;
        record = false;
        begin(screen);
    }

    function dropped(socket: Socket) {
        if (socket === asker) {
            asker = null;
            close();
        }
    }

    // The timer, a second at a time, then the capture.
    Timer {
        id: timer

        onTriggered: {
            if (capture.countdown > 1) {
                capture.countdown--;
                restart();
            } else if (capture.countdown === 1) {
                // The countdown leaves the screen first.
                capture.countdown = 0;
                interval = 150;
                restart();
            } else {
                capture.shoot();
            }
        }
    }

    // The whole screen, frozen for markup; the overlay shows the picked
    // area. grim's file is printed once it is written.
    Process {
        id: grim

        property string file

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === grim.file && capture.stage === "wait") {
                    capture.frozen = grim.file;
                    capture.stage = "markup";
                } else {
                    capture.cancel();
                }
            }
        }
    }

    // A screenshot without markup, saved at once; its path is printed once
    // it is written.
    Process {
        id: saver

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (!path) {
                    capture.cancel();
                    return;
                }
                capture.saved(path);
                capture.shot(path);
            }
        }
    }

    Process {
        id: recorder

        onRunningChanged: {
            if (!running)
                capture.stopping = false;
        }
    }

    // The person's Pictures and Videos (xdg-user-dirs).
    Process {
        command: ["sh", "-c", "xdg-user-dir PICTURES; xdg-user-dir VIDEOS"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const [pictures, videos] = text.split("\n");
                if (pictures)
                    capture.pictures = pictures;
                if (videos)
                    capture.videos = videos;
            }
        }
    }

    Timer {
        running: capture.recording
        interval: 1000
        repeat: true
        onTriggered: {
            const seconds = Math.floor((Date.now() - capture.startedAt) / 1000);
            capture.elapsed = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
        }
    }
}
