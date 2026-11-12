// Dictation, from the quick actions and Super+D: a click starts listening,
// another stops, and what was said goes into the text field that has the focus,
// and to the clipboard. A right click, or Super+Shift+D, only copies. Its button
// shows the state (bar/QuickButton.qml), and then, briefly, where the words went:
// a check when inserted, or a clipboard. The words show as they come, in the text
// field where they would go, or else their last few by the button
// (bar/DictationOverlay.qml).
// dictation/dictate decides where they go; this starts it and shows what it
// says. It understands Parakeet's 25 languages, any of them, once Parakeet is
// downloaded (Extras.qml); until then, the button leads there. Everything runs
// on the computer, and locking the screen discards what is under way.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: dictation

    // "idle", "listening", "writing", or "failed", shown for a moment.
    property string state: "idle"
    readonly property bool listening: state === "listening"
    readonly property bool writing: state === "writing"
    readonly property bool active: listening || writing
    // This dictation only copies.
    property bool onlyCopy

    // Listening: the microphone's level, 0 to 1, whether it seems not to hear,
    // whether the person seems gone, and how long so far, in seconds.
    property real level
    property bool quiet
    property bool idle
    property int seconds
    // While the person speaks: the words so far, and those that may still change,
    // and whether the text field shows them, as a draft that is not yet in it.
    property string draft
    property string draftTail
    property bool draftInline
    // The words, for the shell to show when no text field does
    // (DictationOverlay.qml), above the button, which tells where it is as
    // dictation starts: { screen, rect, edge, depth } (ShellBar.place()); null
    // with no button.
    readonly property bool preview: draft + draftTail !== "" && !draftInline
    readonly property string words: [draft, draftTail].filter(part => part).join(" ")
    property var at: null
    // Where the last words went, briefly: { text, inserted, copied, app }.
    property var result: null
    // A short message of its own: "Needs a download", "No microphone",
    // "Microphone is muted", or "Didn't catch anything"; shown for a moment.
    property string notice
    // What is going on, for the button's tooltip and icon, and for the pill
    // where there is no button.
    readonly property string status: {
        if (notice === "Needs a download")
            return "Dictation needs a download · click to get it";
        if (notice === "No microphone")
            return "No microphone · click for Sound settings";
        if (notice === "Microphone is muted")
            return "Microphone is muted · click to unmute and dictate";
        if (notice)
            return notice;
        if (state === "failed")
            return "It could not be written down";
        if (result?.inserted)
            return "Inserted";
        if (result?.copied)
            return "Copied";
        if (writing)
            return "Writing it down";
        if (listening) {
            const said = quiet ? "Can't hear you" : idle ? "Still listening" : onlyCopy ? "Dictating to copy" : "Dictating";
            const time = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
            return `${said} ${time} · click to stop`;
        }
        if (!available)
            return "Dictation needs a download";
        return "Dictate into this app · right click to only copy";
    }
    // Something the person should see without pointing at the button.
    readonly property bool telling: notice !== "" || quiet && listening || idle && listening || state === "failed"
    readonly property string icon: {
        if (notice === "Needs a download")
            return "M8 2v8.4M4.6 7l3.4 3.4L11.4 7M2.6 13.4h10.8";
        if (notice === "No microphone" || notice === "Microphone is muted" || quiet && listening)
            return "M5.6 4.2a2.4 2.4 0 0 1 4.8 0v3.2a2.4 2.4 0 0 1-4.8 0zM3.4 7.6a4.6 4.6 0 0 0 9.2 0M8 12.2v2M2.5 2.5l11 11";
        if (state === "failed")
            return "M8 3v6.5M8 12.5v.5";
        // A check, or a clipboard.
        if (result?.inserted)
            return "M3 8.5l3.2 3.2L13 4.8";
        if (result?.copied)
            return "M5.5 3.5h-1a1 1 0 0 0-1 1v9a1 1 0 0 0 1 1h7a1 1 0 0 0 1-1v-9a1 1 0 0 0-1-1h-1M6 2.5h4v2H6z";
        return "M2 7v2M5 5v6M8 2.5v11M11 5v6M14 7v2";
    }

    // Parakeet, which writes it down, is downloaded (extras/extras.json).
    readonly property bool available: Extras.list.some(e => e.id === "parakeet" && e.installed)

    // The helper: the source tree's in development (make run), otherwise the
    // installed one.
    function helper(): string {
        const tree = Quickshell.env("DESKTOP_SHELL");
        return tree ? `${tree}/../dictation/dictate` : "/usr/libexec/desktop/dictate";
    }

    function send(message: var) {
        process.write(JSON.stringify(message) + "\n");
    }

    // A dictation that waits for the last one to end.
    property var next: null

    function start(copyOnly: bool) {
        if (process.running) {
            next = copyOnly;
            send({ do: "discard" });
            return;
        }
        notice = "";
        result = null;
        draft = draftTail = "";
        seconds = 0;
        onlyCopy = copyOnly;
        at = null;
        state = "listening";
        const sounds = `DICTATION_SOUNDS=${Settings.dictationSounds ? "1" : ""}`;
        process.command = ["env", sounds, helper(), copyOnly ? "--only-copy" : "--copy"];
        process.running = true;
    }

    // The click: start, or stop; with copyOnly, the right click's.
    function toggle(copyOnly: bool) {
        if (writing)
            return;
        if (listening) {
            send({ do: "stop" });
        } else if (!available) {
            state = "idle";
            if (notice === "Needs a download") {
                notice = "";
                Settings.open(Shortcuts.focused, "assistant");
            } else {
                notice = "Needs a download";
            }
        } else if (!Audio.input) {
            state = "idle";
            if (notice === "No microphone") {
                notice = "";
                Settings.open(Shortcuts.focused, "sound");
            } else {
                notice = "No microphone";
            }
        } else if (Audio.input.audio?.muted && notice !== "Microphone is muted") {
            notice = "Microphone is muted";
            state = "idle";
        } else {
            if (Audio.input.audio?.muted)
                Audio.input.audio.muted = false;
            start(copyOnly ?? false);
        }
    }

    // The right click: discard what is under way, or else dictate only to copy.
    function secondary() {
        if (active)
            cancel();
        else
            toggle(true);
    }

    function cancel() {
        if (active)
            send({ do: "discard" });
        notice = "";
    }

    // The shortcut: pressed, it starts or stops; let go after being held, it stops.
    property real pressedAt
    function press(copyOnly: bool) {
        pressedAt = listening ? 0 : Date.now();
        toggle(copyOnly);
    }
    function release() {
        if (pressedAt && Date.now() - pressedAt > 400 && listening)
            toggle(false);
        pressedAt = 0;
    }

    function heard(line: string) {
        const message = JSON.parse(line);
        switch (message.state) {
        case "listening":
            level = message.level;
            quiet = message.quiet;
            idle = message.idle;
            state = "listening";
            break;
        case "draft":
            draft = message.text;
            draftTail = message.tail;
            draftInline = message.inline;
            break;
        case "writing":
            state = "writing";
            break;
        case "done":
            draft = draftTail = "";
            result = message;
            state = "idle";
            break;
        case "nothing":
            notice = "Didn't catch anything";
            break;
        }
    }

    IpcHandler {
        target: "dictation"

        function toggle(): void {
            dictation.toggle(false);
        }

        function copy(): void {
            dictation.toggle(true);
        }

        function cancel(): void {
            dictation.cancel();
        }

        function press(): void {
            dictation.press(false);
        }

        function release(): void {
            dictation.release();
        }

        // "listening", "writing", "failed", or "idle".
        function state(): string {
            return dictation.state;
        }

        // The words so far, while the person speaks.
        function draft(): string {
            return [dictation.draft, dictation.draftTail].filter(part => part).join(" ");
        }

        // Where the last words went: "inserted", "copied", or "".
        function result(): string {
            const result = dictation.result;
            return !result ? "" : result.inserted ? "inserted" : result.copied ? "copied" : "";
        }

        function notice(): string {
            return dictation.notice;
        }

        function available(): bool {
            return dictation.available;
        }
    }

    Process {
        id: process

        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => dictation.heard(line)
        }
        // Quickshell does not declare the status's type to tooling.
        onExited: exitCode => { // qmllint disable signal-handler-parameters
            dictation.draft = dictation.draftTail = "";
            if (dictation.active)
                dictation.state = exitCode !== 0 && exitCode !== 130 ? "failed" : "idle";
            if (dictation.next !== null) {
                const copyOnly = dictation.next;
                dictation.next = null;
                dictation.start(copyOnly);
            }
        }
    }

    Timer {
        running: dictation.listening
        interval: 1000
        repeat: true
        onTriggered: dictation.seconds++
    }

    // Messages, a failure, and where the words went go by themselves.
    Timer {
        running: dictation.notice !== "" || dictation.state === "failed"
        interval: 4000
        onTriggered: {
            dictation.notice = "";
            if (dictation.state === "failed")
                dictation.state = "idle";
        }
    }
    // Where the words went is a glance.
    Timer {
        running: dictation.result !== null
        interval: 1200
        onTriggered: dictation.result = null
    }

    Connections {
        target: Lock

        function onLockedChanged() {
            if (Lock.locked) {
                dictation.cancel();
                dictation.result = null;
            }
        }
    }
}
