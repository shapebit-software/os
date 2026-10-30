// Welcome, on each person's first login and from Settings > Account, over
// everything with the screens dimmed: the network, only when the computer was
// offline when it opened, with the network panel's Wi-Fi list (WifiList.qml);
// then, only when online, the default browser and the recommended apps, all
// kept unless turned off, which session/app-install installs one after the
// other, going on if Welcome closes; and the ways around the desktop. Every
// step can be skipped; Escape or closing ends it, and it does not open on its
// own again (Settings.welcomed).
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland
import qs.bar
import qs.controls
import qs.services

PanelWindow {
    id: window

    required property ShellScreen modelData

    readonly property bool here: Settings.welcomeOn === (modelData?.name ?? "")
    // Whether NetworkManager reaches the internet, and whether it did not
    // when Welcome opened, which keeps the network step.
    property bool online
    property bool startedOffline
    // Whether the first answer came, before which Welcome waits.
    property bool known
    readonly property list<string> steps: [...(startedOffline ? ["network"] : []), ...(online ? ["browser", "apps"] : []), "around"]
    property int stepIndex
    readonly property string step: steps[Math.min(stepIndex, steps.length - 1)]
    readonly property bool last: stepIndex >= steps.length - 1

    // Each browser: { id, name, from }, as the docs list them.
    readonly property var browsers: [
        { id: "chrome", name: "Google Chrome", from: "From Google, on Flathub" },
        { id: "chromium", name: "Chromium", from: "From Fedora" },
        { id: "firefox", name: "Firefox", from: "From Mozilla, on Flathub" },
        { id: "epiphany", name: "GNOME Web", from: "From GNOME, on Flathub" },
    ]
    // The browser picked, and how its installation goes: "", "queued",
    // "installing", "done", or "failed", with what it is doing or why it
    // failed.
    property string browser
    property string installState
    property string installNote
    // The recommended apps, all from Flathub: { id, name, detail }; those
    // kept, and how their installation goes, as the browser's.
    readonly property var recommended: [
        { id: "app.devsuite.Ptyxis", name: "Terminal", detail: "Ptyxis" },
        { id: "org.gnome.TextEditor", name: "Text Editor", detail: "Plain text and code" },
        { id: "org.gnome.Loupe", name: "Image Viewer", detail: "Loupe" },
        { id: "org.gnome.Papers", name: "Document Viewer", detail: "PDF and other documents" },
        { id: "org.gnome.Showtime", name: "Video Player", detail: "Showtime" },
        { id: "org.gnome.Decibels", name: "Audio Player", detail: "Decibels" },
        { id: "org.gnome.Calculator", name: "Calculator", detail: "GNOME Calculator" },
    ]
    property list<string> kept
    property string appsState
    property string appsNote
    // What is left to install, as app-install's arguments, the first with
    // "browser" or "apps"; and which of the two installs now.
    property var queue: []
    property string current
    readonly property bool browserStarted: ["queued", "installing", "done"].includes(installState)

    // The installer: the source tree's in development (make run), otherwise
    // the installed one.
    readonly property string installerPath: Quickshell.env("DESKTOP_SHELL")
        ? `${Quickshell.env("DESKTOP_SHELL")}/../session/app-install`
        : "/usr/libexec/desktop/app-install"

    function finish() {
        Settings.welcomed = true;
        Settings.welcomeOn = "";
    }

    function next() {
        if (last)
            finish();
        else
            stepIndex += 1;
    }

    function setState(kind: string, state: string, note: string) {
        if (kind === "browser") {
            installState = state;
            installNote = note;
        } else {
            appsState = state;
            appsNote = note;
        }
    }

    function enqueue(args: list<string>) {
        setState(args[0], "queued", "Waiting");
        queue = [...queue, args];
        runNext();
    }

    function runNext() {
        if (installer.running || queue.length === 0)
            return;
        const args = queue[0];
        queue = queue.slice(1);
        current = args[0];
        setState(current, "installing", "Starting");
        installer.command = [installerPath, ...args];
        installer.running = true;
    }

    function installBrowser() {
        if (browser && installState !== "installing" && installState !== "queued")
            enqueue(["browser", browser]);
    }

    function installApps() {
        if (kept.length > 0 && appsState !== "installing" && appsState !== "queued")
            enqueue(["apps", ...kept]);
        next();
    }

    function toggleApp(id: string) {
        kept = kept.includes(id) ? kept.filter(k => k !== id) : [...kept, id];
    }

    function heard(line: string) {
        const message = JSON.parse(line);
        if (message.step)
            setState(current, "installing", message.step);
        else if (message.done !== undefined)
            setState(current, "done", "");
        else if (message.error !== undefined)
            setState(current, "failed", message.error);
    }

    visible: here && known
    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "welcome"
    WlrLayershell.keyboardFocus: here ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    // From the first step, once NetworkManager has said whether it is online.
    function opened() {
        if (!here)
            return;
        stepIndex = 0;
        known = false;
        // Nothing is picked and every app is kept, unless they are still
        // installing.
        if (installState !== "installing" && installState !== "queued") {
            browser = "";
            installState = "";
        }
        if (appsState !== "installing" && appsState !== "queued") {
            kept = recommended.map(a => a.id);
            appsState = "";
        }
        connectivity.opening = true;
        connectivity.running = true;
        keys.forceActiveFocus();
    }

    // It opens at login before this window exists.
    Component.onCompleted: opened()
    onHereChanged: opened()
    onStepChanged: Connectivity.scan(step === "network", false)

    // NetworkManager's view of the internet, now and as the network changes:
    // its connectivity, 4 when full.
    Process {
        id: connectivity

        property bool opening

        command: ["gdbus", "call", "--system", "--dest", "org.freedesktop.NetworkManager",
            "--object-path", "/org/freedesktop/NetworkManager", "--method", "org.freedesktop.DBus.Properties.Get",
            "org.freedesktop.NetworkManager", "Connectivity"]
        stdout: StdioCollector {
            onStreamFinished: {
                window.online = /uint32 4\b/.test(text);
                if (!connectivity.opening)
                    return;
                window.startedOffline = !window.online;
                window.known = true;
                connectivity.opening = false;
            }
        }
    }
    Timer {
        interval: 3000
        repeat: true
        running: window.here
        onTriggered: connectivity.running = true
    }

    Process {
        id: installer

        stdout: SplitParser {
            onRead: line => window.heard(line)
        }
        // It ends having said how it went, unless it stopped; then the next
        // starts.
        onRunningChanged: {
            if (running)
                return;
            if ((window.current === "browser" ? window.installState : window.appsState) === "installing")
                window.setState(window.current, "failed", "The installation stopped");
            window.current = "";
            window.runNext();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.05, 0.04, 0.09, 0.45)
    }

    Item {
        id: keys

        focus: true
        Keys.onEscapePressed: window.finish()
    }

    PopoverFrame {
        anchors.centerIn: parent
        padding: 28

        // Clicks on Welcome stay in it.
        TapHandler {}

        Column {
            width: 520
            spacing: 18

            // The title, and where it is among the steps.
            Item {
                width: parent.width
                height: title.height

                Text {
                    id: title
                    text: ({ network: "Connect to the internet", browser: "Choose a browser",
                        apps: "Recommended apps", around: "Getting around" })[window.step]
                    color: Theme.ink
                    font { family: Theme.font; pixelSize: 20; weight: Font.DemiBold }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 6

                    Repeater {
                        model: window.steps.length

                        Rectangle {
                            required property int index
                            width: 7
                            height: 7
                            radius: 3.5
                            color: index === window.stepIndex ? Theme.accent : Theme.veil(0.15)
                        }
                    }
                }
            }

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: ({
                    network: window.online ? "You're connected." : "Join a Wi-Fi network to install a browser. You can do it later from the network panel.",
                    browser: "It's installed for you and opens your links. You can change it later.",
                    apps: "These are installed for you. Turn off any you don't want.",
                    around: "A few things to know about the desktop.",
                })[window.step]
                color: Theme.inkSoft
                font { family: Theme.font; pixelSize: 13 }
            }

            WifiList {
                visible: window.step === "network" && Networking.wifiEnabled && Connectivity.wifi !== null
                width: parent.width
                listHeight: 240
            }
            Text {
                visible: window.step === "network" && Connectivity.wifi === null
                text: "This computer has no Wi-Fi. Plug in a network cable to connect."
                color: Theme.inkFaint
                font { family: Theme.font; pixelSize: 12 }
            }

            // The browsers, none picked at first.
            Grid {
                visible: window.step === "browser"
                columns: 2
                spacing: 10

                Repeater {
                    model: window.browsers

                    Rectangle {
                        id: card

                        required property var modelData
                        readonly property bool picked: window.browser === modelData.id
                        readonly property bool locked: ["queued", "installing", "done"].includes(window.installState)

                        width: 255
                        height: 64
                        radius: Theme.rounded ? 10 : 0
                        color: picked ? Theme.accentSoft : cardHover.hovered && !locked ? Theme.veil(0.08) : Theme.veil(0.04)
                        border.width: picked ? 1.5 : 0
                        border.color: Theme.accent

                        Column {
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: card.modelData.name
                                color: Theme.ink
                                font { family: Theme.font; pixelSize: 14; weight: Font.Medium }
                            }
                            Text {
                                text: card.picked && window.installState === "done"
                                    ? "Installed · your default browser" : card.modelData.from
                                color: Theme.inkFaint
                                font { family: Theme.font; pixelSize: 11 }
                            }
                        }
                        HoverHandler {
                            id: cardHover
                            cursorShape: card.locked ? Qt.ArrowCursor : Qt.PointingHandCursor
                        }
                        TapHandler {
                            enabled: !card.locked
                            onTapped: {
                                window.browser = card.modelData.id;
                                if (window.installState === "failed")
                                    window.installState = "";
                            }
                        }
                    }
                }
            }
            Text {
                visible: window.step === "browser" && ["queued", "installing", "failed"].includes(window.installState)
                width: parent.width
                wrapMode: Text.Wrap
                text: window.installState === "failed" ? `Couldn't install: ${window.installNote}` : `${window.installNote}…`
                color: window.installState === "failed" ? Theme.danger : Theme.inkFaint
                font { family: Theme.font; pixelSize: 12 }
            }

            // The recommended apps, each with a switch, all on at first.
            Column {
                visible: window.step === "apps"
                width: parent.width
                spacing: 2

                Repeater {
                    model: window.recommended

                    Item {
                        id: app

                        required property var modelData
                        readonly property bool on: window.kept.includes(modelData.id)

                        width: parent.width
                        height: 40

                        Column {
                            x: 4
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: app.modelData.name
                                color: app.on ? Theme.ink : Theme.inkFaint
                                font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                            }
                            Text {
                                text: app.modelData.detail
                                color: Theme.inkFaint
                                font { family: Theme.font; pixelSize: 11 }
                            }
                        }
                        Switch {
                            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                            enabled: !["queued", "installing"].includes(window.appsState)
                            on: app.on
                            onToggled: window.toggleApp(app.modelData.id)
                        }
                    }
                }
            }
            Text {
                visible: window.step === "apps" && window.appsState === "failed"
                width: parent.width
                wrapMode: Text.Wrap
                text: `Couldn't install: ${window.appsNote}`
                color: Theme.danger
                font { family: Theme.font; pixelSize: 12 }
            }

            // The ways around the desktop.
            Column {
                visible: window.step === "around"
                width: parent.width
                spacing: 10

                Repeater {
                    model: [
                        { keys: "Super", text: "Opens Apps, as does the Apps button on the dock. Drag an app onto a workspace map to open it there." },
                        { keys: "Super+Alt+←/→", text: "Goes to the workspace before or after. Drag a window onto the “+” on the dock for a new one." },
                        { keys: "Super+arrows", text: "Moves between windows; with Shift, the window goes along." },
                        { keys: "Super+/", text: "Shows every keyboard shortcut." },
                    ]

                    Row {
                        id: tip

                        required property var modelData

                        width: parent.width
                        spacing: 14

                        Rectangle {
                            width: 128
                            height: 28
                            radius: Theme.rounded ? 6 : 0
                            color: Theme.veil(0.06)

                            Text {
                                anchors.centerIn: parent
                                text: tip.modelData.keys
                                color: Theme.ink
                                font { family: Theme.mono; pixelSize: 11; weight: Font.DemiBold }
                            }
                        }
                        Text {
                            width: parent.width - 128 - 14
                            anchors.verticalCenter: parent.verticalCenter
                            wrapMode: Text.Wrap
                            text: tip.modelData.text
                            color: Theme.inkSoft
                            font { family: Theme.font; pixelSize: 12 }
                        }
                    }
                }
                Text {
                    readonly property string note: window.current === "browser" ? window.installNote : window.appsNote

                    visible: window.current !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: `Still installing ${window.current === "browser" ? "your browser" : "your apps"}: ${note}…`
                        + (window.queue.length > 0 ? " The apps follow." : "")
                    color: Theme.inkFaint
                    font { family: Theme.font; pixelSize: 12 }
                }
                Text {
                    visible: window.installState === "failed" || window.appsState === "failed"
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: [window.installState === "failed" ? `The browser couldn't be installed: ${window.installNote}` : "",
                        window.appsState === "failed" ? `The apps couldn't be installed: ${window.appsNote}` : ""].filter(t => t).join(" ")
                    color: Theme.danger
                    font { family: Theme.font; pixelSize: 12 }
                }
            }

            // Skip and close on the left; back and the step's action on the
            // right.
            Item {
                width: parent.width
                height: 34

                DialogButton {
                    visible: !window.last
                    text: "Skip all"
                    onActivated: window.finish()
                }
                Row {
                    anchors.right: parent.right
                    spacing: 8

                    DialogButton {
                        visible: window.stepIndex > 0
                        text: "Back"
                        onActivated: window.stepIndex -= 1
                    }
                    DialogButton {
                        visible: (window.step === "browser" && !window.browserStarted) || window.step === "apps"
                        text: "Skip"
                        onActivated: window.next()
                    }
                    DialogButton {
                        readonly property bool installs: (window.step === "browser" && !window.browserStarted)
                            || (window.step === "apps" && window.kept.length > 0)

                        strong: true
                        enabled: window.step !== "browser" || !installs || window.browser !== ""
                        opacity: enabled ? 1 : 0.45
                        text: installs ? (window.step === "browser" && window.installState === "failed" ? "Try again" : "Install")
                            : window.last ? "Done" : "Next"
                        onActivated: {
                            if (!installs)
                                window.next();
                            else if (window.step === "browser")
                                window.installBrowser();
                            else
                                window.installApps();
                        }
                    }
                }
            }
        }
    }
}
