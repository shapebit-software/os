// A page of Settings for the keyboard layouts to switch between with
// Super+Space: the chosen ones, each with a button to remove it, and a search
// to add others.
pragma ComponentBehavior: Bound
import QtQuick
import qs.services

Column {
    id: page

    // The chosen layouts: the setting, or the compositor's until it is set.
    readonly property list<string> chosen: Settings.keyboards.length ? Settings.keyboards : Keyboard.layouts
    readonly property string query: search.text.trim().toLowerCase()
    readonly property var found: query ? Object.keys(Keyboard.names)
        .filter(code => !chosen.includes(code)
            && (code + " " + Keyboard.names[code]).toLowerCase().includes(query))
        .slice(0, 30) : []

    function set(codes: list<string>) {
        Settings.keyboards = codes;
    }

    spacing: 22

    component List: Rectangle {
        default property alias rows: column.data

        width: page.width
        height: column.height + 2
        visible: column.children.length > 1
        color: "white"
        border.color: "#d8dbde"

        Column {
            id: column
            x: 1
            y: 1
            width: parent.width - 2
        }
    }

    component Entry: Item {
        id: entry

        required property string modelData
        required property int index
        property string action
        signal acted

        width: parent?.width ?? 0
        height: 48

        Rectangle {
            visible: entry.index > 0
            width: parent.width
            height: 1
            color: "#e6e8ea"
        }
        Text {
            x: 16
            width: 28
            anchors.verticalCenter: parent.verticalCenter
            text: Keyboard.languageOf(entry.modelData)
            color: "#1d2022"
            font { family: Theme.font; pixelSize: 11; weight: Font.Bold }
        }
        Text {
            x: 52
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - actionText.width - 32
            elide: Text.ElideRight
            text: Keyboard.nameOf(entry.modelData)
            color: "#1d2022"
            font { family: Theme.font; pixelSize: 13 }
        }
        Text {
            id: actionText
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: entry.action
            color: entry.action === "Remove" ? "#b63132" : Theme.accent
            font { family: Theme.font; pixelSize: 12; weight: Font.Medium }

            TapHandler {
                onTapped: entry.acted()
            }
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    List {
        Repeater {
            model: page.chosen

            Entry {
                // The last layout stays.
                action: page.chosen.length > 1 ? "Remove" : ""
                onActed: page.set(page.chosen.filter(c => c !== modelData))
            }
        }
    }

    Rectangle {
        width: page.width
        height: 32
        color: "white"
        border.color: "#d1d5d8"

        TextInput {
            id: search

            anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
            anchors.verticalCenter: parent.verticalCenter
            color: "#1d2022"
            selectionColor: Theme.accent
            font { family: Theme.font; pixelSize: 12 }
            clip: true

            Text {
                visible: !search.text
                text: "Add a keyboard"
                color: "#65696f"
                font: search.font
            }
        }
    }

    List {
        Repeater {
            model: page.found

            Entry {
                action: "Add"
                onActed: {
                    page.set([...page.chosen, modelData]);
                    search.text = "";
                }
            }
        }
    }
}
