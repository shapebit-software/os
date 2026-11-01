// Dictation, from the quick actions and Super+D: a click starts listening,
// another stops, and what was said goes into the text field that has the focus.
// Its button shows the state (bar/QuickActions.qml). When it is not sure of the
// place, the text waits in a card to be told where (bar/DictationOverlay.qml).
// dictation/dictate decides all that; this starts it
// and shows what it says. It understands the keyboard layout's language, or any,
// by the person's choice for that layout. Everything runs on the computer, and
// locking the screen discards everything, the last dictation too.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: dictation

    // "idle", "listening", "writing", "waiting" (a card), or "failed" (a card
    // when there is audio to try again, otherwise only a message).
    property string state: "idle"
    readonly property bool listening: state === "listening"
    readonly property bool writing: state === "writing"
    readonly property bool waiting: state === "waiting"
    readonly property bool retryable: state === "failed" && process.running
    readonly property bool active: state !== "idle" && state !== "failed" || retryable

    // Listening: the microphone's level, 0 to 1, whether it seems not to hear,
    // whether the person seems gone, and how long so far, in seconds.
    property real level
    property bool quiet
    property bool idle
    property int seconds
    // Writing it down, in percent.
    property int progress
    // Waiting: the text; where it would go, as the helper says; and the app.
    property string text
    property string where: "none"
    property string app
    // The app's name, for people.
    readonly property string appName: {
        const entry = app ? DesktopEntries.heuristicLookup(app) : null;
        return entry?.name ?? app ?? "";
    }
    // A short message of its own: "No microphone", "Microphone is muted", or
    // "Didn't catch anything"; shown for a moment.
    property string notice
    // What is going on, for the button's tooltip and icon, and for the pill
    // where there is no button.
    readonly property string status: {
        if (notice === "No microphone")
            return "No microphone · click for Sound settings";
        if (notice === "Microphone is muted")
            return "Microphone is muted · click to unmute and dictate";
        if (notice)
            return notice;
        if (state === "failed")
            return retryable ? "It could not be written down" : "Dictation failed";
        if (writing)
            return progress > 0 ? `Writing it down ${progress}%` : "Writing it down";
        if (waiting)
            return "Click to keep talking";
        if (listening) {
            const said = quiet ? "Can't hear you" : idle ? "Still listening" : "Dictating";
            const time = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
            return `${said} ${time} · ${language === "auto" ? "any language" : language.toUpperCase()} · click to stop`;
        }
        return last ? "Dictate into this app · right click for the last one" : "Dictate into this app";
    }
    // Something the person should see without pointing at the button.
    readonly property bool telling: notice !== "" || quiet && listening || idle && listening
        || state === "failed" && !retryable
    readonly property string icon: {
        if (notice === "No microphone" || notice === "Microphone is muted" || quiet && listening)
            return "M5.6 4.2a2.4 2.4 0 0 1 4.8 0v3.2a2.4 2.4 0 0 1-4.8 0zM3.4 7.6a4.6 4.6 0 0 0 9.2 0M8 12.2v2M2.5 2.5l11 11";
        if (state === "failed")
            return "M8 3v6.5M8 12.5v.5";
        if (writing)
            return "M3 13l1-3.5 7-7 2.5 2.5-7 7zM9.8 3.7l2.5 2.5";
        if (waiting)
            return "M2.5 4.5h11M2.5 8h11M2.5 11.5h7";
        return "M2 7v2M5 5v6M8 2.5v11M11 5v6M14 7v2";
    }
    // The person is using the card with the keyboard or editing its text; the
    // card then has the focus, so the helper's "where" waits until it is back.
    property bool cardFocused
    // Text that was delivered, or copied, that can be brought back.
    property string last

    readonly property string language: {
        const layout = Keyboard.layouts[Keyboard.active];
        return Settings.dictationAnyLanguage.includes(layout) ? "auto"
            : (Keyboard.languages[layout] ?? "auto").toLowerCase();
    }

    // The helper: the source tree's in development (make run), otherwise the
    // installed one.
    function helper(): string {
        const tree = Quickshell.env("DESKTOP_SHELL");
        return tree ? `${tree}/../dictation/dictate` : "/usr/libexec/desktop/dictate";
    }

    function send(message: var) {
        process.write(JSON.stringify(message) + "\n");
    }

    function start(held: bool) {
        notice = "";
        text = "";
        seconds = 0;
        cardFocused = false;
        const sounds = `DICTATION_SOUNDS=${Settings.dictationSounds ? "1" : ""}`;
        process.command = ["env", sounds, helper(), language, ...(held ? ["--held"] : [])];
        process.running = true;
    }

    // The click: start, stop, or keep talking into a card.
    function toggle() {
        if (writing)
            return;
        if (listening) {
            send({ do: "stop" });
        } else if (waiting) {
            cardFocused = false;
            seconds = 0;
            send({ do: "add" });
        } else if (retryable) {
            send({ do: "discard" });
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
            start(false);
        }
    }

    // The right click: discard what is under way, or else bring back the last.
    function secondary() {
        if (process.running)
            cancel();
        else if (last)
            recall();
    }

    function cancel() {
        if (process.running)
            send({ do: "discard" });
        notice = "";
    }

    function recall() {
        start(true);
        send({ do: "hold", text: last });
    }

    // The shortcut: pressed, it starts or stops, or goes to a waiting card;
    // let go after being held, it stops.
    property real pressedAt
    function press() {
        if (waiting || retryable) {
            cardFocused = true;
            return;
        }
        pressedAt = listening ? 0 : Date.now();
        toggle();
    }
    function release() {
        if (pressedAt && Date.now() - pressedAt > 400 && listening)
            toggle();
        pressedAt = 0;
    }

    function setText(edited: string) {
        text = edited;
        send({ do: "text", text: edited });
    }

    // The focus goes back to the application first, and with it the field.
    function deliver(what: string) {
        const wasFocused = cardFocused;
        cardFocused = false;
        afterFocus.what = what;
        afterFocus.interval = wasFocused ? 150 : 1;
        afterFocus.restart();
    }

    function chooseLanguage(any: bool) {
        const layout = Keyboard.layouts[Keyboard.active];
        const others = Settings.dictationAnyLanguage.filter(l => l !== layout);
        Settings.dictationAnyLanguage = any ? [...others, layout] : others;
        if (process.running)
            send({ do: "language", language: language });
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
        case "writing":
            progress = message.progress;
            state = "writing";
            break;
        case "waiting":
            text = message.text;
            if (!cardFocused) {
                where = message.where;
                app = message.app;
            }
            state = "waiting";
            break;
        case "failed":
            state = "failed";
            break;
        case "done":
            last = message.text;
            break;
        case "nothing":
            notice = "Didn't catch anything";
            break;
        }
    }

    IpcHandler {
        target: "dictation"

        function toggle(): void {
            dictation.toggle();
        }

        function cancel(): void {
            dictation.cancel();
        }

        function press(): void {
            dictation.press();
        }

        function release(): void {
            dictation.release();
        }

        // "listening", "writing", "waiting", "failed", or "idle".
        function state(): string {
            return dictation.state;
        }

        // What Waiting would deliver, and to where.
        function where(): string {
            return dictation.waiting ? dictation.where : "";
        }

        function notice(): string {
            return dictation.notice;
        }

        function deliver(what: string): void {
            dictation.deliver(what);
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
            dictation.cardFocused = false;
            dictation.state = exitCode !== 0 && exitCode !== 130 ? "failed" : "idle";
        }
    }

    Timer {
        id: afterFocus

        property string what

        onTriggered: dictation.send({ do: what })
    }

    Timer {
        running: dictation.listening
        interval: 1000
        repeat: true
        onTriggered: dictation.seconds++
    }

    // Messages and a failure with nothing to try again go by themselves.
    Timer {
        running: dictation.notice !== "" || dictation.state === "failed" && !dictation.retryable
        interval: 4000
        onTriggered: {
            dictation.notice = "";
            if (dictation.state === "failed")
                dictation.state = "idle";
        }
    }

    Connections {
        target: Lock

        function onLockedChanged() {
            if (Lock.locked) {
                dictation.cancel();
                dictation.last = "";
            }
        }
    }
}
