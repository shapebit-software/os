// Choose the time zone of the installed system.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import Installer

Step {
    id: page

    property string timeZone: TimeZones.current
    readonly property var zone: TimeZones.zone(timeZone)
    // Changes every few seconds, so that the clocks follow the time.
    property int tick: 0
    readonly property var matches: {
        const words = search.text.toLowerCase().split(/\s+/).filter(word => word)
        return TimeZones.zones.filter(zone => words.every(
            word => zone.city.toLowerCase().includes(word) || zone.region.toLowerCase().includes(word)))
    }

    function time(id) {
        tick
        return TimeZones.time(id)
    }

    // Up and Down in the search field choose among the matches.
    function choose(step) {
        const index = matches.findIndex(zone => zone.id === timeZone)
        const next = Math.max(0, Math.min(matches.length - 1, index + step))
        if (matches.length > 0) {
            timeZone = matches[next].id
            list.positionViewAtIndex(next, ListView.Contain)
        }
    }

    number: 4
    label: qsTr("Time zone")
    heading: qsTr("Time zone")
    subtitle: qsTr("Search for a city near you.")

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: ++page.tick
    }

    Panel {
        Layout.fillWidth: true
        implicitHeight: 70

        Column {
            anchors.verticalCenter: parent.verticalCenter
            x: 18
            spacing: 3
            Text {
                objectName: "city"
                text: page.zone.city
                color: Theme.text
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Mono { text: page.zone.id + " · " + page.zone.offset }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 18
            text: page.time(page.timeZone)
            color: Theme.text
            font.family: Theme.mono
            font.pixelSize: 24
        }
    }

    Field {
        id: search
        objectName: "search"
        Layout.fillWidth: true
        initialFocus: true
        placeholderText: qsTr("Search city or region")
        Keys.onDownPressed: page.choose(1)
        Keys.onUpPressed: page.choose(-1)
    }

    Panel {
        Layout.fillWidth: true
        implicitHeight: 34 * 6 + 2

        ListView {
            id: list
            objectName: "zones"
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            model: page.matches
            T.ScrollBar.vertical: Bar {}
            // Opens with the chosen zone in view.
            Component.onCompleted: positionViewAtIndex(
                page.matches.findIndex(zone => zone.id === page.timeZone), ListView.Center)

            delegate: ListRow {
                required property var modelData
                width: list.width - 10
                chosen: modelData.id === page.timeZone
                onClicked: page.timeZone = modelData.id
                contentItem: RowLayout {
                    spacing: 10
                    Text {
                        text: modelData.city
                        color: Theme.text
                        font.pixelSize: 13
                        font.weight: chosen ? Font.DemiBold : Font.Normal
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.region
                        color: Theme.faint
                        font.pixelSize: 12
                    }
                    Mono { text: modelData.offset }
                    Mono {
                        Layout.preferredWidth: 60
                        horizontalAlignment: Text.AlignRight
                        text: page.time(modelData.id)
                        color: Theme.text
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: qsTr("No city or region matches.")
            color: Theme.faint
            font.pixelSize: 13
        }
    }
}
