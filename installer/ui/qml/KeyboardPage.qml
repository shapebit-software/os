// Choose the keyboard layout. The choice applies at once, so what is typed
// on the following pages is what the installed system will see.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import Installer

Step {
    id: page

    readonly property string layout: Keyboard.layout
    readonly property var matches: {
        const words = search.text.toLowerCase().split(/\s+/).filter(word => word)
        return Keyboard.layouts.filter(entry => words.every(word => entry.name.toLowerCase().includes(word)))
    }

    // Up and Down in the search field choose among the matches.
    function choose(step) {
        const index = matches.findIndex(entry => entry.id === Keyboard.layout)
        const next = Math.max(0, Math.min(matches.length - 1, index + step))
        if (matches.length > 0) {
            Keyboard.layout = matches[next].id
            grid.positionViewAtIndex(next, GridView.Contain)
        }
    }

    number: 2
    label: qsTr("Keyboard")
    heading: qsTr("Keyboard layout")
    subtitle: qsTr("Choose the layout that matches the keys on your keyboard.")
    contentWidth: 640

    Panel {
        Layout.fillWidth: true
        implicitHeight: keys.implicitHeight + 50

        Column {
            id: keys
            anchors.horizontalCenter: parent.horizontalCenter
            y: 12
            spacing: 7

            Repeater {
                model: Keyboard.rows
                Row {
                    id: keyRow
                    required property var modelData
                    required property int index
                    // Each row starts a little further right, as on a keyboard.
                    leftPadding: index * 12
                    spacing: 7
                    Repeater {
                        model: keyRow.modelData
                        Rectangle {
                            required property string modelData
                            width: 36
                            height: 36
                            color: "#1f222c"
                            border.color: Theme.border
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData
                                color: Theme.text
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }
        }
        Mono {
            objectName: "layoutName"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            text: Keyboard.name(Keyboard.layout)
        }
    }

    Field {
        id: search
        objectName: "search"
        Layout.fillWidth: true
        initialFocus: true
        placeholderText: qsTr("Search keyboard layouts")
        Keys.onDownPressed: page.choose(1)
        Keys.onUpPressed: page.choose(-1)
    }

    Panel {
        Layout.fillWidth: true
        implicitHeight: 138

        GridView {
            id: grid
            objectName: "layouts"
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            cellWidth: (width - 10) / 2
            cellHeight: 34
            model: page.matches
            T.ScrollBar.vertical: Bar {}
            // Opens with the chosen layout in view.
            Component.onCompleted: positionViewAtIndex(
                page.matches.findIndex(entry => entry.id === Keyboard.layout), GridView.Center)

            delegate: ListRow {
                required property var modelData
                width: grid.cellWidth
                chosen: modelData.id === Keyboard.layout
                onClicked: Keyboard.layout = modelData.id
                contentItem: Text {
                    text: modelData.name
                    color: Theme.text
                    font.pixelSize: 13
                    font.weight: chosen ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: grid.count === 0
            text: qsTr("No layout matches.")
            color: Theme.faint
            font.pixelSize: 13
        }
    }
}
