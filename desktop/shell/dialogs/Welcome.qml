// Welcome, on each person's first login and from Settings > Account, over
// everything with the screens dimmed: the network, only when the computer was
// offline when it opened, with the network panel's Wi-Fi list (WifiList.qml);
// then, only when online, the default browser, the recommended apps, and what
// can be downloaded beyond the OS (Extras.qml), the apps and the downloads all
// kept unless turned off. Those steps only choose; the next, when anything was
// chosen, adds it all to the one queue (Downloads.qml), which installs it one
// after the other, and shows how it goes. Back from it cancels; Next waits until all is in. Last, the
// ways around the desktop. Skip all, Escape, or closing ends Welcome, with
// what is installing going on, and it does not open on its own again
// (Settings.welcomed). Closed without having been online, it is offered
// again once online (SetupReminder.qml).
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
    // Whether NetworkManager reaches the internet; whether it did not when
    // Welcome opened, which keeps the network step; and whether it has since,
    // which keeps the steps that need it if the network drops.
    property bool online
    property bool startedOffline
    property bool wasOnline
    // Whether the first answer came, before which Welcome waits.
    property bool known
    readonly property list<string> steps: [...(startedOffline ? ["network"] : []), ...(wasOnline ? ["browser", "apps"] : []),
        ...(wasOnline && offered.length > 0 ? ["extras"] : []), ...(wasOnline && chosen ? ["install"] : []), "around"]
    property int stepIndex
    readonly property string step: steps[Math.min(stepIndex, steps.length - 1)]
    readonly property bool last: stepIndex >= steps.length - 1

    // Each browser: { id, name, from }, as the docs list them.
    readonly property var browsers: [
        { id: "chrome", name: "Google Chrome", from: "From Google, on Flathub · Google's terms apply" },
        { id: "chromium", name: "Chromium", from: "From Fedora" },
        { id: "firefox", name: "Firefox", from: "From Mozilla, on Flathub" },
        { id: "epiphany", name: "GNOME Web", from: "From GNOME, on Flathub" },
    ]
    // The browser picked.
    property string browser
    // The recommended apps, all from Flathub: { id, name, detail }; and those
    // kept.
    readonly property var recommended: [
        { id: "org.gnome.TextEditor", name: "Text Editor", detail: "Plain text and code" },
        { id: "org.gnome.Loupe", name: "Image Viewer", detail: "Loupe" },
        { id: "org.gnome.Papers", name: "Document Viewer", detail: "PDF and other documents" },
        { id: "org.gnome.Showtime", name: "Video Player", detail: "Showtime" },
        { id: "org.gnome.Decibels", name: "Audio Player", detail: "Decibels" },
        { id: "org.gnome.Calculator", name: "Calculator", detail: "GNOME Calculator" },
    ]
    property list<string> kept

    // The extras offered, fixed when Welcome opens, so that the steps stay the same
    // while they download; and those kept.
    property var offered: []
    property list<string> keptExtras

    // What was chosen, for the queue: { kind, target, name, label }, the
    // label as the install step shows it.
    readonly property bool chosen: browser !== "" || kept.length > 0 || keptExtras.length > 0
    readonly property var choices: [
        ...(browser ? [browsers.find(b => b.id === browser)].map(b => ({ kind: "browser", target: b.id, name: b.name, label: b.name })) : []),
        ...recommended.filter(a => kept.includes(a.id)).map(a => ({ kind: "app", target: a.id, name: a.name, label: a.name })),
        ...offered.filter(e => keptExtras.includes(e.id))
            .map(e => ({ kind: "extra", target: e.id, name: e.name, label: `${e.name} · ${Extras.sizeOf(e)}` })),
    ]
    // Each, one line on the install step, with how it goes: { label, state,
    // note, percent }, the state "" (not asked yet), "queued", "installing",
    // "done", or "failed"; and whether any is still to come, failed, or all
    // is in.
    readonly property var tasks: choices.map(c => Object.assign({ label: c.label }, progressOf(c)))
    readonly property bool working: tasks.some(t => t.state === "queued" || t.state === "installing")
    readonly property bool failed: tasks.some(t => t.state === "failed")
    readonly property bool ready: tasks.every(t => t.state === "done")

    function keyOf(choice: var): string {
        return `${choice.kind}:${choice.target}`;
    }

    // From the queue; an extra may be in from before.
    function progressOf(choice: var): var {
        const key = keyOf(choice);
        const job = Downloads.byKey(key);
        if (choice.kind === "extra" && (Extras.list.find(e => e.id === choice.target)?.installed ?? false))
            return { state: "done", note: "", percent: 100 };
        if (Downloads.pending.includes(key) || job?.state === "queued")
            return { state: "queued", note: "Waiting", percent: 0 };
        if (!job || job.action !== "install" || job.state === "cancelled")
            return { state: "", note: "Waiting", percent: 0 };
        if (job.state === "running")
            return { state: "installing", note: job.note, percent: job.percent };
        return { state: job.state, note: job.error, percent: job.state === "done" ? 100 : 0 };
    }

    function offer() {
        offered = Extras.writable ? Extras.missing : [];
        // On, unless the computer has too little memory for one.
        keptExtras = offered.filter(e => e.fits !== false).map(e => e.id);
    }

    // Everything chosen that is not in or on its way.
    function installAll() {
        for (const choice of choices) {
            if (!["queued", "installing", "done"].includes(progressOf(choice).state))
                Downloads.add(choice.kind, "install", choice.target, choice.name, false);
        }
    }

    // Stops what has not finished; what is in stays.
    function cancelAll() {
        Downloads.cancel(choices.filter(c => ["queued", "installing"].includes(progressOf(c).state)).map(c => keyOf(c)));
    }

    function back() {
        if (step === "install")
            cancelAll();
        stepIndex -= 1;
    }

    function finish() {
        Settings.setupPending = !wasOnline;
        Settings.welcomed = true;
        Settings.welcomeOn = "";
    }

    function next() {
        if (last)
            finish();
        else
            stepIndex += 1;
    }

    function toggleApp(id: string) {
        kept = kept.includes(id) ? kept.filter(k => k !== id) : [...kept, id];
    }

    visible: here && known && Extras.listed
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
        wasOnline = false;
        // Nothing is picked and everything is kept, unless what was chosen
        // is still installing.
        if (!working) {
            browser = "";
            kept = recommended.map(a => a.id);
            offer();
        }
        connectivity.opening = true;
        connectivity.running = true;
        keys.forceActiveFocus();
    }

    // At login, the list may come after Welcome opens.
    Connections {
        target: Extras

        function onListedChanged() {
            if (window.here)
                window.offer();
        }
    }

    // It opens at login before this window exists.
    Component.onCompleted: opened()
    onHereChanged: opened()
    onStepChanged: {
        Connectivity.scan(step === "network", false);
        if (step === "install")
            installAll();
    }

    // NetworkManager's view of the internet, now and as the network changes:
    // its connectivity, 4 when full.
    Process {
        id: connectivity

        property bool opening

        command: Connectivity.onlineQuery
        stdout: StdioCollector {
            onStreamFinished: {
                window.online = Connectivity.online(text);
                if (window.online)
                    window.wasOnline = true;
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

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim(0.45)
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
                        apps: "Recommended apps", extras: "Optional downloads", install: "Installing",
                        around: "Getting around" })[window.step]
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
                    extras: "These run on this computer. Turn off any you don't want, and get them later in Settings > Assistant.",
                    install: window.ready ? "Everything is in." : "Installing what you chose. Back cancels it.",
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
                        readonly property bool locked: window.working

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
                                text: card.picked && window.tasks[0]?.state === "done"
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
                            onTapped: window.browser = card.modelData.id
                        }
                    }
                }
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
                            enabled: !window.working
                            on: app.on
                            onToggled: window.toggleApp(app.modelData.id)
                        }
                    }
                }
            }

            // The extras, each with a switch, on at first if the computer has memory enough.
            Column {
                visible: window.step === "extras"
                width: parent.width
                spacing: 8

                Repeater {
                    model: window.offered

                    Item {
                        id: extraItem

                        required property var modelData
                        readonly property bool on: window.keptExtras.includes(modelData.id)

                        width: parent.width
                        height: extraText.height + 8

                        Column {
                            id: extraText

                            x: 4
                            width: parent.width - 70
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: `${extraItem.modelData.name} · ${Extras.sizeOf(extraItem.modelData)}`
                                color: extraItem.on ? Theme.ink : Theme.inkFaint
                                font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                            }
                            Text {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: extraItem.modelData.detail
                                color: Theme.inkFaint
                                font { family: Theme.font; pixelSize: 11 }
                            }
                        }
                        Switch {
                            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                            enabled: !window.working
                            on: extraItem.on
                            onToggled: {
                                const id = extraItem.modelData.id;
                                window.keptExtras = extraItem.on ? window.keptExtras.filter(k => k !== id) : [...window.keptExtras, id];
                            }
                        }
                    }
                }
            }

            // What was chosen, each with how it goes.
            Column {
                visible: window.step === "install"
                width: parent.width
                spacing: 8

                Repeater {
                    model: window.tasks

                    Column {
                        id: task

                        required property var modelData

                        width: parent.width
                        spacing: 4

                        Item {
                            width: parent.width
                            height: Math.max(taskName.height, taskState.height)

                            Text {
                                id: taskName
                                x: 4
                                width: parent.width * 0.45
                                elide: Text.ElideRight
                                text: task.modelData.label
                                color: Theme.ink
                                font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                            }
                            Text {
                                id: taskState
                                anchors { right: parent.right; rightMargin: 4 }
                                width: parent.width * 0.5
                                horizontalAlignment: Text.AlignRight
                                wrapMode: Text.Wrap
                                text: ({ "": "Waiting", queued: "Waiting", done: "Done", failed: `Couldn't install: ${task.modelData.note}`,
                                    installing: `${task.modelData.note}${task.modelData.percent > 0 ? ` ${task.modelData.percent}%` : "…"}` })[task.modelData.state]
                                color: task.modelData.state === "failed" ? Theme.danger : Theme.inkFaint
                                font { family: Theme.font; pixelSize: 12 }
                            }
                        }
                        Rectangle {
                            x: 4
                            width: parent.width - 8
                            height: 4
                            radius: 2
                            color: Theme.veil(0.08)

                            Rectangle {
                                width: parent.width * (task.modelData.state === "done" ? 1 : task.modelData.percent / 100)
                                height: parent.height
                                radius: 2
                                color: task.modelData.state === "failed" ? Theme.danger : Theme.accent
                            }
                        }
                    }
                }
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
                    visible: window.working
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: "What you chose is still installing, and it goes on if you close this. Settings > Downloads shows how it goes."
                    color: Theme.inkFaint
                    font { family: Theme.font; pixelSize: 12 }
                }
                Text {
                    visible: window.failed && !window.working
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: "Some of what you chose couldn't be installed. Go back to try again."
                    color: Theme.danger
                    font { family: Theme.font; pixelSize: 12 }
                }
            }

            // Skip all on the left; back and the step's action on the
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
                        onActivated: window.back()
                    }
                    // On the install step, Next waits for all of it, and
                    // tries again what failed.
                    DialogButton {
                        readonly property bool retries: window.step === "install" && window.failed && !window.working

                        strong: true
                        enabled: retries || window.step !== "install" || window.ready
                        opacity: enabled ? 1 : 0.45
                        text: retries ? "Try again" : window.last ? "Done" : "Next"
                        onActivated: {
                            if (retries)
                                window.installAll();
                            else
                                window.next();
                        }
                    }
                }
            }
        }
    }
}
