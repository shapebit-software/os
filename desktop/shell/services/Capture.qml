// Screenshots and recordings of the screen, the voice, and the camera,
// through the capture overlay (CaptureOverlay.qml). For screenshots and screen
// recordings the person picks an area they draw, a window, or a whole screen,
// then captures it; after the timer, if set, a recording starts, or the
// screenshot is saved to Pictures/Screenshots, or, with Settings.captureMarkup,
// first opens for markup, then is saved or copied. Screen recordings go to
// Videos/Recordings, with the camera in a bubble if Settings.captureBubble;
// voice recordings, Opus from the default microphone, to Music/Recordings; and
// camera recordings, VP9 and Opus in WebM, to Videos/Camera (capture/camera,
// which also writes what the camera sees for the overlay to show). With
// Settings.captureSkipSilence, voice and camera recordings lose their silences
// once they end (capture/skip-silence). Applications ask for screenshots
// through the portal (Portal.qml): the overlay then takes a screenshot only, and the
// application gets the file. Applications sharing the screen ask what to
// share the same way (SharePicker.qml), also while recording.
pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: capture

    // Recording ends at once for the person; the recorder may still be
    // finishing the file, and Skip silence cutting it, and nothing else starts
    // until they have.
    readonly property bool recording: (recorder.running || camcorder.running) && !stopping
    readonly property bool busy: recorder.running || camcorder.running || starting || cutter.running
    readonly property bool cutting: cutter.running
    property bool stopping
    // A camera recording, until the camera's view has let go of the camera,
    // which only one program can read at a time.
    property bool starting
    property date startedAt
    // The recording's length so far, as m:ss.
    property string elapsed: "0:00"

    // The overlay's screen, and its stage: "select" while picking, "wait"
    // during the timer, "markup" with the screenshot, or none.
    property ShellScreen screen: null
    property string stage
    // What to capture: "Shot", a screenshot; "Screen", a screen recording;
    // "Voice"; or "Camera". Only the first two pick a part of the screen.
    property string kind: "Shot"
    readonly property bool record: kind !== "Shot"
    readonly property bool picks: kind === "Shot" || kind === "Screen"
    // What to pick: "Area", "Window", or "Screen"; and the timer for screen
    // and camera recordings, in seconds, 0 for none.
    property string mode: "Area"
    property int delay
    // The recording going on or last made: its kind, its file, and whether
    // Skip silence cuts it when it ends.
    property string recordingKind
    property string file
    property bool skipping

    // Whether there is a camera, looked for each time the overlay opens; it
    // is on only while it shows or records.
    property bool hasCamera
    // Where the camera shows outside the overlay: during a camera recording
    // and its timer, "bubble", round, with Settings.captureBubble, otherwise
    // "preview"; "bubble" too over a screen recording, and while picking for
    // one; or "".
    readonly property string cameraWindow: camcorder.running || starting || stage === "wait" && kind === "Camera"
        ? (Settings.captureBubble ? "bubble" : "preview")
        : Settings.captureBubble && hasCamera && (kind === "Screen" && stage !== "" && stage !== "markup"
            || recordingKind === "Screen" && recorder.running) ? "bubble" : ""
    // Whether the camera shows, in the overlay or outside it; and the picture
    // of it that capture/camera writes, 25 times a second.
    readonly property bool cameraShown: cameraWindow !== "" || stage === "select" && kind === "Camera"
    readonly property string cameraPicture: `${runtime}/camera.jpg`
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
    property string music: `${Quickshell.env("HOME")}/Music`

    function begin(screen: ShellScreen) {
        if (stage || busy && !SharePicker.asking)
            return;
        Hyprland.refreshToplevels();
        finder.running = true;
        capture.screen = screen;
        stage = "select";
    }

    function take(area: rect) {
        capture.area = area;
        if (mode === "Area")
            lastArea = area;
        countdown = kind === "Screen" || kind === "Camera" ? delay : 0;
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
        if (kind === "Screen") {
            // Frames come steadily, not only when the screen changes, so the
            // recording ends as soon as it is stopped, and plays evenly.
            // With Settings.captureMicrophone, the default microphone too.
            started(`${videos}/Recordings/Recording ${stamp()}.mp4`, false);
            recorder.command = ["sh", "-c", 'mkdir -p "${1%/*}" && exec wf-recorder --no-damage $3 -g "$2" -f "$1"',
                "sh", file, geometry(), Settings.captureMicrophone ? "--audio" : ""];
            recorder.running = true;
            close();
            return;
        }
        if (kind === "Voice") {
            // Speech in mono Opus at 32 kb/s: small, and clear.
            started(`${music}/Recordings/Voice ${stamp()}.opus`, Settings.captureSkipSilence);
            recorder.command = ["sh", "-c", 'mkdir -p "${1%/*}" && exec ffmpeg -nostdin -loglevel error -f pulse -i default -ac 1 -c:a libopus -b:a 32k "$1"',
                "sh", file];
            recorder.running = true;
            close();
            return;
        }
        if (kind === "Camera") {
            // The camera records once its view has let go of it.
            started(`${videos}/Camera/Video ${stamp()}.webm`, Settings.captureSkipSilence && Settings.cameraMicrophone);
            camcorder.command = [helper("camera"), cameraPicture, "--record", file]
                .concat(Settings.cameraMicrophone ? ["--microphone"] : []);
            starting = true;
            if (!viewer.running)
                film();
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
        const still = `${runtime}/capture-${Date.now()}.png`;
        grim.command = ["sh", "-c", 'mkdir -p "$4" && rm -f "$1"/capture-*.png && grim -o "$2" "$3" && echo "$3"',
            "sh", runtime, screen.name, still, `${pictures}/Screenshots`];
        grim.file = still;
        grim.running = true;
    }

    function started(path: string, skip: bool) {
        file = path;
        recordingKind = kind;
        skipping = skip;
        startedAt = new Date();
        elapsed = "0:00";
    }

    // The date and time in file names.
    function stamp(): string {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss");
    }

    // Where a screenshot is saved: Pictures/Screenshots, by date and time.
    function screenshotPath(): string {
        return `${pictures}/Screenshots/Screenshot ${stamp()}.png`;
    }

    function film() {
        starting = false;
        camcorder.running = true;
    }

    // A recording has ended, its file written; Skip silence cuts it if set.
    function ended() {
        stopping = false;
        if (!skipping)
            return;
        skipping = false;
        cutter.command = [helper("skip-silence"), file];
        cutter.running = true;
    }

    // A helper: the source tree's in development (make run), otherwise the
    // installed one.
    function helper(name: string): string {
        const tree = Quickshell.env("DESKTOP_SHELL");
        return tree ? `${tree}/../capture/${name}` : `/usr/libexec/desktop/${name}`;
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
        // SIGINT: wf-recorder and ffmpeg finish the file.
        (camcorder.running ? camcorder : recorder).signal(2);
    }

    function ask(socket: Socket, question: var) {
        const screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        if (stage || recorder.running || !screen) {
            Portal.answer(socket, {});
            return;
        }
        request = question;
        asker = socket;
        kind = "Shot";
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

    // Screen and voice recordings.
    Process {
        id: recorder

        onRunningChanged: {
            if (!running)
                capture.ended();
        }
    }

    // Skip silence, after a voice or camera recording.
    Process {
        id: cutter
    }

    // The camera, shown while it is not recorded; once it has let go of the
    // camera, a camera recording starts.
    Process {
        id: viewer

        command: [capture.helper("camera"), capture.cameraPicture]
        running: capture.cameraShown && !capture.starting && !camcorder.running
        onRunningChanged: {
            if (!running && capture.starting)
                capture.film();
        }
    }

    // A camera recording, shown as it is recorded.
    Process {
        id: camcorder

        onRunningChanged: {
            if (!running)
                capture.ended();
        }
    }

    // Whether there is a camera.
    Process {
        id: finder

        command: [capture.helper("camera"), "--find"]
        running: true
        onExited: code => capture.hasCamera = code === 0 // qmllint disable signal-handler-parameters
    }

    // The person's Pictures, Videos, and Music (xdg-user-dirs).
    Process {
        command: ["sh", "-c", "xdg-user-dir PICTURES; xdg-user-dir VIDEOS; xdg-user-dir MUSIC"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const [pictures, videos, music] = text.split("\n");
                if (pictures)
                    capture.pictures = pictures;
                if (videos)
                    capture.videos = videos;
                if (music)
                    capture.music = music;
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
