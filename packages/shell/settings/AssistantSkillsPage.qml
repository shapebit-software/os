// A page of Settings > Assistant: what the assistant can do. Its skills,
// instructions it reads when a request needs them (assistant/skills.py): the
// system's, to read, and the person's own, to add, change, or delete. Then its
// tools, the actions it takes (assistant/actions.py), each with whether it
// runs at once or asks first.
pragma ComponentBehavior: Bound
import QtQuick
import qs.controls
import qs.services

Column {
    id: page

    // The skill being written: null, or { name, description, temperature,
    // instructions }, with previous, its name before ("" for a new one).
    property var draft: null
    property string previous
    // The skill whose instructions show.
    property string shown

    // The temperatures offered: the model's own, or one of these.
    readonly property var temperatures: [["Model's own", null], ["Exact · 0.2", 0.2], ["Balanced · 0.5", 0.5], ["Creative · 0.8", 0.8]]

    function edit(skill: var) {
        Assistant.skillError = "";
        previous = skill?.name ?? "";
        draft = { name: skill?.name ?? "", description: skill?.description ?? "",
                  temperature: skill?.temperature ?? null, instructions: skill?.instructions ?? "" };
        nameField.text = draft.name;
        descriptionField.text = draft.description;
        instructionsEdit.text = draft.instructions;
    }

    function save() {
        Assistant.saveSkill({ name: nameField.text, description: descriptionField.text, temperature: draft.temperature,
                              instructions: instructionsEdit.text }, previous);
    }

    function riskOf(tool: var): string {
        if (tool.risk === "read")
            return "Runs at once";
        if (tool.risk === "confirm")
            return "Asks every time";
        return Assistant.grants.includes(tool.group) ? "Allowed without asking" : "Asks first, until allowed";
    }

    spacing: 12

    Connections {
        target: Assistant

        function onSkillSaved() {
            page.draft = null;
        }
    }

    component Heading: Item {
        property alias text: label.text
        default property alias trailing: right.data

        width: page.width
        height: 34

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.textStrong
            font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
        }
        Item {
            id: right
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    component List: Rectangle {
        default property alias rows: column.data

        width: page.width
        height: column.height + 2
        color: Theme.surface
        border.color: Theme.line

        Column {
            id: column
            x: 1
            y: 1
            width: parent.width - 2
        }
    }

    component Field: Rectangle {
        id: box

        property alias text: field.text
        property string hint

        width: parent?.width ?? 0
        height: 32
        color: Theme.surface
        border.color: Theme.lineStrong

        TextInput {
            id: field
            anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
            color: Theme.textStrong
            selectionColor: Theme.accent
            font { family: Theme.font; pixelSize: 12 }
            clip: true

            Text {
                visible: !field.text
                text: box.hint
                color: Theme.textMuted
                font: field.font
            }
        }
    }

    component Link: Text {
        signal tapped

        color: Theme.accent
        font { family: Theme.font; pixelSize: 12; weight: Font.Medium }

        TapHandler {
            onTapped: parent.tapped()
        }
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }

    Text {
        width: page.width
        wrapMode: Text.Wrap
        text: "Skills are instructions the assistant reads when a request needs them, such as how to write a longer "
            + "text. A skill can also set the temperature: low for exact actions, higher for writing."
        color: Theme.textMuted
        font { family: Theme.font; pixelSize: 12 }
    }

    Heading {
        text: "Skills"

        DialogButton {
            visible: page.draft === null
            text: "New skill"
            onActivated: page.edit(null)
        }
    }

    // The skill being written.
    List {
        visible: page.draft !== null

        Column {
            width: parent.width
            padding: 16
            spacing: 10

            Field {
                id: nameField
                width: parent.width - 32
                hint: "Name, such as meeting-notes"
            }
            Field {
                id: descriptionField
                width: parent.width - 32
                hint: "When to use it, such as: Sum up a meeting's notes into decisions and tasks."
            }
            SettingsChoice {
                options: page.temperatures
                selected: page.draft?.temperature ?? null
                onPicked: value => page.draft = Object.assign({}, page.draft, { temperature: value })
            }
            Rectangle {
                width: parent.width - 32
                height: 180
                color: Theme.surface
                border.color: Theme.lineStrong

                Flickable {
                    id: flick
                    anchors { fill: parent; margins: 10 }
                    contentHeight: instructionsEdit.height
                    clip: true

                    TextEdit {
                        id: instructionsEdit
                        width: flick.width
                        height: Math.max(flick.height, contentHeight)
                        wrapMode: TextEdit.Wrap
                        color: Theme.textStrong
                        selectionColor: Theme.accent
                        font { family: Theme.font; pixelSize: 12 }

                        Text {
                            visible: !instructionsEdit.text
                            text: "The instructions: what to do, step by step, and how the answer should look."
                            color: Theme.textMuted
                            font: instructionsEdit.font
                        }
                    }
                }
            }
            Text {
                visible: Assistant.skillError !== ""
                width: parent.width - 32
                wrapMode: Text.Wrap
                text: Assistant.skillError
                color: Theme.dangerInk
                font { family: Theme.font; pixelSize: 12 }
            }
            Row {
                spacing: 8

                DialogButton {
                    text: "Save"
                    strong: true
                    onActivated: page.save()
                }
                DialogButton {
                    text: "Cancel"
                    onActivated: page.draft = null
                }
            }
        }
    }

    List {
        Repeater {
            model: Assistant.skills

            Item {
                id: skill

                required property var modelData
                required property int index
                readonly property bool open: page.shown === modelData.name

                width: parent?.width ?? 0
                height: about.height + 24

                Rectangle {
                    visible: skill.index > 0
                    width: parent.width
                    height: 1
                    color: Theme.lineSoft
                }
                Column {
                    id: about
                    x: 16
                    y: 12
                    width: parent.width - 32 - actions.width - 16
                    spacing: 3

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: skill.modelData.name
                        color: Theme.textStrong
                        font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: [skill.modelData.description, skill.modelData.own ? "Yours" : "System's, read only",
                               skill.modelData.temperature !== null ? `temperature ${skill.modelData.temperature}` : ""]
                            .filter(t => t).join(" · ")
                        color: Theme.textMuted
                        font { family: Theme.font; pixelSize: 12 }
                    }
                    Text {
                        visible: skill.open
                        width: parent.width
                        topPadding: 6
                        wrapMode: Text.Wrap
                        text: skill.modelData.instructions
                        color: Theme.textBody
                        font { family: Theme.mono; pixelSize: 11 }
                    }
                }
                Row {
                    id: actions
                    anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 14 }
                    spacing: 14

                    Link {
                        text: skill.open ? "Hide" : "Read"
                        onTapped: page.shown = skill.open ? "" : skill.modelData.name
                    }
                    Link {
                        visible: skill.modelData.own
                        text: "Edit"
                        onTapped: page.edit(skill.modelData)
                    }
                    Link {
                        visible: skill.modelData.own
                        text: "Delete"
                        color: Theme.dangerInk
                        onTapped: Assistant.deleteSkill(skill.modelData.name)
                    }
                }
            }
        }
    }

    Heading {
        text: "Tools"
    }

    List {
        Repeater {
            model: Assistant.tools

            Item {
                id: tool

                required property var modelData
                required property int index

                width: parent?.width ?? 0
                height: texts.height + 24

                Rectangle {
                    visible: tool.index > 0
                    width: parent.width
                    height: 1
                    color: Theme.lineSoft
                }
                Column {
                    id: texts
                    x: 16
                    y: 12
                    width: parent.width - 32 - risk.width - 16
                    spacing: 3

                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: tool.modelData.description
                        color: Theme.textStrong
                        font { family: Theme.font; pixelSize: 13 }
                    }
                    Text {
                        text: tool.modelData.name
                        color: Theme.textMuted
                        font { family: Theme.mono; pixelSize: 11 }
                    }
                }
                Text {
                    id: risk
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    text: page.riskOf(tool.modelData)
                    color: Theme.textBody
                    font { family: Theme.font; pixelSize: 12 }
                }
            }
        }
    }
}
