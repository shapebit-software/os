// A question from an application (Question.qml), as the file chooser shows:
// over everything, with the screens dimmed. The application's icon, the
// person's picture for their details, or the launcher's; the title, the
// subtitle, and the body; what the kind asks: the choices, the applications
// to open with, the launcher's name, or the wallpaper's preview; and the
// buttons. Enter grants, a double click on an application opens with it,
// and Escape dismisses.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: window

    required property ShellScreen modelData

    readonly property var request: Question.request
    // The question is on one screen; the others are only dimmed.
    readonly property bool asking: request !== null && Question.screen === (modelData?.name ?? "")
    readonly property string kind: request?.kind ?? ""
    // The choices made, by id: "true" or "false" for a box, otherwise the
    // id of an option.
    property var chosen: ({})
    // The application to open with, by id.
    property string app
    readonly property bool canGrant: kind !== "open-with" || (request?.apps ?? []).includes(app)

    visible: request !== null
    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "question"
    WlrLayershell.keyboardFocus: asking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    onRequestChanged: {
        const initial = {};
        for (const choice of request?.choices ?? [])
            initial[choice.id] = choice.value;
        chosen = initial;
        app = request?.app || (request?.apps?.[0] ?? "");
        name.text = request?.name ?? "";
        focusQuestion();
    }
    onAskingChanged: focusQuestion()

    // The launcher's name if it can change, otherwise the question, for its
    // keys.
    function focusQuestion() {
        if (!asking)
            return;
        if (request.editName) {
            name.forceActiveFocus();
            name.selectAll();
        } else {
            content.forceActiveFocus();
        }
    }

    function grant() {
        if (canGrant)
            Question.grant({ choices: chosen, app: app, name: name.text });
    }

    function choose(id: string, value: string) {
        chosen = Object.assign({}, chosen, { [id]: value });
    }

    // An icon by name, or by path.
    function iconSource(icon: string): string {
        return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, true);
    }

    function entry(id: string): DesktopEntry {
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.05, 0.04, 0.09, 0.45)
    }

    PopoverFrame {
        visible: window.asking
        anchors.centerIn: parent
        padding: 0

        Column {
            id: content

            width: 400
            topPadding: 24
            spacing: 18

            Keys.onEscapePressed: Question.dismiss()
            Keys.onReturnPressed: window.grant()
            Keys.onEnterPressed: window.grant()

            Column {
                x: 24
                width: parent.width - 48
                spacing: 8

                Avatar {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: window.kind === "account"
                    width: 56
                    height: 56
                    round: true
                }
                Text {
                    width: parent.width
                    visible: window.kind === "account"
                    bottomPadding: 6
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: Account.displayName
                    color: Theme.ink
                    font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                }
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: window.kind !== "account" && source.toString() !== ""
                    implicitSize: 40
                    source: window.kind === "launcher" && window.request?.image ? "file://" + window.request.image
                        : window.iconSource(window.request?.icon ?? "")
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: window.request?.title ?? ""
                    color: Theme.ink
                    font { family: Theme.font; pixelSize: 15; weight: Font.DemiBold }
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: window.request?.subtitle ?? ""
                    color: Theme.inkSoft
                    font { family: Theme.font; pixelSize: 13 }
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: window.request?.body ?? ""
                    color: Theme.inkFaint
                    font { family: Theme.font; pixelSize: 12 }
                }
            }

            // The wallpaper's preview.
            Image {
                x: 24
                visible: window.kind === "wallpaper"
                width: parent.width - 48
                height: Math.round(width * 9 / 16)
                source: visible ? "file://" + window.request.image : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: width * 2
            }

            // The launcher's name.
            Rectangle {
                x: 24
                visible: window.kind === "launcher"
                width: parent.width - 48
                height: 34
                color: Theme.veil(0.06)

                TextInput {
                    id: name

                    anchors { left: parent.left; right: parent.right; leftMargin: 11; rightMargin: 11 }
                    anchors.verticalCenter: parent.verticalCenter
                    readOnly: !(window.request?.editName ?? false)
                    color: Theme.ink
                    selectionColor: Theme.accent
                    font { family: Theme.font; pixelSize: 13 }
                    clip: true
                    onAccepted: window.grant()
                    Keys.onEscapePressed: Question.dismiss()
                }
            }

            // The choices: a box to tick, or one option of several.
            Column {
                x: 24
                visible: (window.request?.choices?.length ?? 0) > 0
                width: parent.width - 48
                spacing: 10

                Repeater {
                    model: window.request?.choices ?? []

                    Column {
                        id: choice

                        required property var modelData
                        readonly property bool box: modelData.options.length === 0

                        width: parent.width
                        spacing: 6

                        Item {
                            width: parent.width
                            height: 20

                            Text {
                                width: parent.width - (choice.box ? toggle.width + 12 : 0)
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: choice.modelData.label
                                color: Theme.ink
                                font { family: Theme.font; pixelSize: 13 }
                            }
                            Switch {
                                id: toggle

                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                visible: choice.box
                                on: window.chosen[choice.modelData.id] === "true"
                                onToggled: window.choose(choice.modelData.id, on ? "false" : "true")
                            }
                        }
                        Flow {
                            visible: !choice.box
                            width: parent.width
                            spacing: 2

                            Repeater {
                                model: choice.modelData.options

                                Rectangle {
                                    id: option

                                    required property var modelData
                                    readonly property bool current: window.chosen[choice.modelData.id] === modelData.id

                                    width: optionLabel.width + 20
                                    height: 28
                                    color: current ? Theme.accentSoft : Theme.veil(optionHover.hovered ? 0.07 : 0.03)

                                    Text {
                                        id: optionLabel
                                        anchors.centerIn: parent
                                        text: option.modelData.label
                                        color: option.current ? Theme.accent : Theme.inkSoft
                                        font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
                                    }
                                    TapHandler {
                                        onTapped: window.choose(choice.modelData.id, option.modelData.id)
                                    }
                                    HoverHandler {
                                        id: optionHover
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // The applications to open with, or that there are none.
            Text {
                width: parent.width
                visible: window.kind === "open-with" && !(window.request?.apps?.length)
                horizontalAlignment: Text.AlignHCenter
                text: "No application can open this."
                color: Theme.inkFaint
                font { family: Theme.font; pixelSize: 12 }
            }
            ListView {
                id: apps

                x: 12
                visible: window.kind === "open-with" && count > 0
                width: parent.width - 24
                height: Math.min(contentHeight, 280)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: window.kind === "open-with" ? window.request.apps : []

                delegate: Rectangle {
                    id: candidate

                    required property string modelData
                    readonly property DesktopEntry entry: window.entry(modelData)
                    readonly property bool current: window.app === modelData

                    width: apps.width
                    height: 40
                    color: current ? Theme.accentSoft : Theme.veil(candidateHover.hovered ? 0.06 : 0)

                    IconImage {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 24
                        source: Quickshell.iconPath(candidate.entry?.icon ?? "", "application-x-executable")
                    }
                    Text {
                        x: 46
                        width: parent.width - 58
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: candidate.entry?.name ?? candidate.modelData
                        color: candidate.current ? Theme.accent : Theme.ink
                        font { family: Theme.font; pixelSize: 13; weight: candidate.current ? Font.Medium : Font.Normal }
                    }

                    TapHandler {
                        onTapped: window.app = candidate.modelData
                        onDoubleTapped: {
                            window.app = candidate.modelData;
                            window.grant();
                        }
                    }
                    HoverHandler {
                        id: candidateHover
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            Item {
                width: parent.width
                height: 60

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.veil(0.08)
                }

                Row {
                    anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    spacing: 4

                    DialogButton {
                        text: window.request?.deny ?? "Cancel"
                        onActivated: Question.refuse()
                    }
                    DialogButton {
                        visible: window.canGrant
                        text: window.request?.grant ?? "OK"
                        strong: true
                        onActivated: window.grant()
                    }
                }
            }
        }
    }
}
