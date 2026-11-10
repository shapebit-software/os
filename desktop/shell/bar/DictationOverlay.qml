// What dictation shows beyond its button, in the bottom right corner of the
// focused screen: the draft while the person speaks, which the pointer passes
// through; a card when the text has to wait for the person to say where it
// goes; and, only with no button to show the state, a pill, so that an open
// microphone is never out of sight. It takes no keyboard, so the application keeps its text field,
// until the person asks for the card with the shortcut or edits the text.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.controls
import qs.services

PanelWindow {
    id: overlay

    required property ShellScreen modelData

    readonly property bool noButton: Settings.quickActions === "Hot corner"
        || Settings.hiddenItems.includes("dictation")
    readonly property bool pill: noButton && (Dictation.listening || Dictation.writing || Dictation.notice !== ""
        || Dictation.state === "failed" && !Dictation.retryable)
    readonly property bool card: Dictation.waiting || Dictation.retryable
    readonly property bool preview: !card && Dictation.draft + Dictation.draftTail !== ""

    // The card's actions, the first the main one.
    readonly property var actions: {
        if (Dictation.retryable)
            return [{ label: "Try again", act: () => Dictation.send({ do: "retry" }) },
                { label: "Discard", act: () => Dictation.cancel() }];
        const app = Dictation.appName;
        return [
            ...(Dictation.where === "field" ? [{ label: app ? `Insert into ${app}` : "Insert", act: () => Dictation.deliver("insert") }] : []),
            { label: "Copy", act: () => Dictation.deliver("copy") },
            ...(Dictation.where === "unknown" || Dictation.where === "none"
                ? [{ label: app ? `Type into ${app}` : "Type anyway", act: () => Dictation.deliver("type") }] : []),
            { label: "Keep talking", act: () => Dictation.toggle() },
            { label: "Discard", act: () => Dictation.cancel() },
        ];
    }
    property int selected
    // Clear of the dock, and of the hot corner's recording pill.
    readonly property int fromRight: Theme.gap + (Capture.recording && Settings.quickActions === "Hot corner" ? 110 : 0)
    readonly property int fromBottom: Theme.gap + 14 + (Settings.dock === "Bottom" ? Theme.stripHeight + Theme.gap : 0)

    function status(): string {
        if (Dictation.retryable)
            return "It could not be written down. The recording is still here.";
        const app = Dictation.appName || "This window";
        switch (Dictation.where) {
        case "field":
            return `Ready for the text field in ${app}`;
        case "password":
            return "Dictation never goes into a password field";
        case "unknown":
            return `${app} doesn't say if a text field is ready`;
        case "nowindow":
            return "No window to put this in";
        }
        return `${app} has no text field here. Click one, or choose:`;
    }

    screen: modelData
    visible: (pill || card || preview) && Hyprland.focusedMonitor?.name === modelData.name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dictation"
    WlrLayershell.keyboardFocus: Dictation.cardFocused ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: true; right: true }
    implicitWidth: 460 + fromRight
    implicitHeight: 280 + fromBottom
    color: "transparent"
    mask: Region { item: overlay.card ? frame : pillShape }

    onCardChanged: selected = 0

    // Enter is always the safe, main action until the person moves.
    Connections {
        target: Dictation

        function onCardFocusedChanged() {
            overlay.selected = 0;
        }
    }

    // The draft, its newest lines, above the pill if there is one; the words that may
    // still change are faint.
    PopoverFrame {
        visible: overlay.preview
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: overlay.fromRight
            bottomMargin: overlay.fromBottom + (overlay.pill ? pillShape.height + 8 : 0) }
        padding: 12

        Item {
            width: 420
            height: Math.min(draftText.implicitHeight, 3 * draftMetrics.lineSpacing)
            clip: true

            FontMetrics {
                id: draftMetrics
                font: draftText.font
            }
            Text {
                id: draftText

                function escaped(text: string): string {
                    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
                }

                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                text: `${escaped(Dictation.draft)} <font color="${Theme.inkFaint}">${escaped(Dictation.draftTail)}</font>`
                color: Theme.ink
                font { family: Theme.font; pixelSize: 14 }
                Accessible.role: Accessible.StatusBar
                Accessible.name: `${Dictation.draft} ${Dictation.draftTail}`
            }
        }
    }

    // The pill.
    Rectangle {
        id: pillShape

        visible: overlay.pill && !overlay.card
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: overlay.fromRight; bottomMargin: overlay.fromBottom }
        width: pillRow.width + 24
        height: 32
        radius: 16
        color: Dictation.state === "failed" ? Theme.dangerFill : Theme.accent
        Accessible.role: Accessible.StatusBar
        Accessible.name: said.text

        RowLayout {
            id: pillRow

            anchors.centerIn: parent
            spacing: 9

            DictationBars {
                visible: Dictation.listening || Dictation.writing
            }
            Text {
                id: said
                text: Dictation.status
                color: Theme.textOnAccent
                font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
            }
        }
        TapHandler {
            onTapped: Dictation.toggle()
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: Dictation.cancel()
        }
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }

    // The card.
    PopoverFrame {
        id: frame

        visible: overlay.card
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: overlay.fromRight; bottomMargin: overlay.fromBottom }
        padding: 14

        FocusScope {
            width: 420
            height: cardColumn.implicitHeight
            focus: Dictation.cardFocused && !editor.editing

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    Dictation.cardFocused = false;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    overlay.actions[overlay.selected]?.act();
                } else if (event.key === Qt.Key_Tab) {
                    overlay.selected = (overlay.selected + 1) % overlay.actions.length;
                } else if (event.key === Qt.Key_Backtab) {
                    overlay.selected = (overlay.selected + overlay.actions.length - 1) % overlay.actions.length;
                } else {
                    return;
                }
                event.accepted = true;
            }

            ColumnLayout {
                id: cardColumn

                width: parent.width
                spacing: 10

                // The text, which a click lets the person correct.
                Flickable {
                    visible: !Dictation.retryable
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(editor.contentHeight, 110)
                    contentHeight: editor.contentHeight
                    clip: true

                    TextEdit {
                        id: editor

                        property bool editing

                        function finish() {
                            Dictation.setText(text);
                            editing = false;
                            Dictation.cardFocused = false;
                        }

                        width: parent.width
                        wrapMode: TextEdit.Wrap
                        readOnly: !editing
                        focus: editing
                        color: Theme.ink
                        selectionColor: Theme.accent
                        selectByMouse: editing
                        font { family: Theme.font; pixelSize: 14 }
                        Accessible.role: Accessible.EditableText
                        Accessible.name: "Dictated text"

                        // While editing, the text stays what the person is making.
                        Binding on text {
                            when: !editor.editing
                            value: Dictation.text
                            restoreMode: Binding.RestoreNone
                        }
                        Keys.onReturnPressed: finish()
                        Keys.onEnterPressed: finish()
                        Keys.onEscapePressed: {
                            editing = false;
                            text = Dictation.text;
                            Dictation.cardFocused = false;
                        }
                        TapHandler {
                            enabled: !editor.editing
                            onTapped: {
                                editor.editing = true;
                                Dictation.cardFocused = true;
                                editor.forceActiveFocus();
                            }
                        }
                        HoverHandler {
                            cursorShape: Qt.IBeamCursor
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: overlay.status()
                    color: Theme.inkFaint
                    font { family: Theme.font; pixelSize: 12 }
                    Accessible.role: Accessible.StatusBar
                    Accessible.name: text
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: overlay.actions

                        DialogButton {
                            id: action

                            required property var modelData
                            required property int index

                            text: modelData.label
                            strong: index === 0 && Dictation.where === "field" || Dictation.retryable && index === 0
                            border.width: Dictation.cardFocused && !editor.editing && overlay.selected === index ? 2 : 0
                            border.color: Theme.accent
                            onActivated: {
                                if (editor.editing)
                                    editor.finish();
                                modelData.act();
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.label
                        }
                    }
                }
            }
        }
    }
}
