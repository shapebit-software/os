// Settings > Apps (Apps.qml), as a store: a search, all apps or only the
// installed, the categories, and a card for each app. A click on one shows its
// details (AppPage.qml), where it can be removed.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.controls
import qs.services

Column {
    id: page

    readonly property string allView: "All apps"
    readonly property string installedView: "Installed"
    property string view: allView
    readonly property bool showsAll: view === allView
    readonly property var entries: showsAll ? Apps.found
        : Apps.installed.filter(a => (a.name + " " + a.summary).toLowerCase().includes(Apps.query.toLowerCase()))
    readonly property string problem: showsAll ? Apps.findError : Apps.installedError
    // The categories by AppStream's names, as people read them.
    readonly property var categories: [["All", ""], ["Games", "Game"], ["Graphics", "Graphics"], ["Internet", "Network"],
        ["Media", "AudioVideo"], ["Office", "Office"], ["Development", "Development"], ["Education", "Education"],
        ["Science", "Science"], ["System", "System"], ["Utilities", "Utility"]]
    readonly property int columns: Math.max(1, Math.floor((width + 12) / 312))
    signal opened(var app)

    spacing: 16

    onVisibleChanged: {
        if (visible) {
            Apps.open();
            Qt.callLater(focusSearch);
        }
    }

    function focusSearch() {
        query.forceActiveFocus();
    }

    Item {
        width: page.width
        height: 36

        Rectangle {
            anchors { left: parent.left; right: views.left; rightMargin: 16 }
            height: parent.height
            color: "white"
            border.color: "#d1d5d8"

            Icon {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 13
                color: "#5f6469"
                strokeWidth: 1.5
                strokes: "M2.4 7a4.6 4.6 0 1 0 9.2 0a4.6 4.6 0 1 0-9.2 0zM10.4 10.4L14 14"
            }
            TextInput {
                id: query

                anchors { left: parent.left; right: parent.right; leftMargin: 34; rightMargin: 12 }
                anchors.verticalCenter: parent.verticalCenter
                color: "#1d2022"
                selectionColor: Theme.accent
                font { family: Theme.font; pixelSize: 13 }
                clip: true
                onTextChanged: Apps.search(text)

                Text {
                    visible: !query.text
                    text: "Search"
                    color: "#65696f"
                    font: query.font
                }
            }
        }
        SettingsChoice {
            id: views

            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            options: [page.allView, page.installedView]
            selected: page.view
            onPicked: value => page.view = value
        }
    }

    Flow {
        visible: page.showsAll
        width: page.width
        spacing: 6

        Repeater {
            model: page.categories

            Rectangle {
                id: chip

                required property var modelData
                readonly property bool current: Apps.category === modelData[1]

                width: chipLabel.width + 24
                height: 28
                color: current ? Theme.accent : chipHover.hovered ? "#e1e3e6" : "#eceff1"

                Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: chip.modelData[0]
                    color: chip.current ? "white" : "#3e4348"
                    font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
                }
                TapHandler {
                    onTapped: Apps.pickCategory(chip.modelData[1])
                }
                HoverHandler {
                    id: chipHover
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    Grid {
        visible: page.entries.length > 0
        width: page.width
        columns: page.columns
        spacing: 12

        Repeater {
            model: page.entries

            Rectangle {
                id: card

                required property var modelData
                readonly property var mine: Apps.byId(modelData.id)
                readonly property var work: Apps.work[modelData.id] ?? null
                readonly property bool busy: work !== null && !work.error
                readonly property bool canInstall: !mine && Apps.listed && Apps.installedError === ""
                readonly property bool canRemove: !page.showsAll && (mine?.removable ?? false)

                width: (page.width - (page.columns - 1) * 12) / page.columns
                height: 104
                color: "white"
                border.color: cardHover.hovered ? "#b9bdc2" : "#d8dbde"

                TapHandler {
                    onTapped: page.opened(card.modelData)
                }
                HoverHandler {
                    id: cardHover
                    cursorShape: Qt.PointingHandCursor
                }

                IconImage {
                    x: 14
                    y: 14
                    implicitSize: 48
                    asynchronous: true
                    source: card.modelData.icon ? `file://${card.modelData.icon}`
                        : Quickshell.iconPath(card.modelData.id, "application-x-executable")
                }
                Column {
                    x: 74
                    y: 12
                    width: parent.width - x - 14
                    spacing: 2

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: card.modelData.name
                        color: "#1d2022"
                        font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
                    }
                    Text {
                        width: parent.width
                        height: 30
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: card.work?.error ?? card.modelData.summary
                        color: card.work?.error ? "#b63132" : "#65696f"
                        font { family: Theme.font; pixelSize: 11 }
                    }
                }

                // What can be done, or how it goes. Removing asks first, on
                // the app's details.
                Rectangle {
                    readonly property bool acts: !card.busy && (card.canInstall || card.canRemove)

                    anchors { right: parent.right; bottom: parent.bottom; rightMargin: 12; bottomMargin: 10 }
                    width: action.width + (acts ? 24 : 0)
                    height: 24
                    color: !acts ? "transparent" : card.canInstall ? Theme.accent : actionHover.hovered ? "#e1e3e6" : "#eceff1"

                    Text {
                        id: action
                        anchors.centerIn: parent
                        text: card.busy ? `${card.work.note}…`
                            : card.modelData.builtIn ? "Built in"
                            : card.canInstall ? "Install"
                            : card.canRemove ? "Remove"
                            : card.mine ? "Installed" : ""
                        color: parent.acts ? (card.canInstall ? "white" : "#b63132") : "#65696f"
                        font { family: Theme.font; pixelSize: 11; weight: Font.Medium }
                    }
                    TapHandler {
                        enabled: parent.acts
                        onTapped: {
                            if (card.canInstall)
                                Apps.install(card.modelData.id);
                            else
                                page.opened(Object.assign({ confirming: true }, card.modelData));
                        }
                    }
                    HoverHandler {
                        id: actionHover
                        enabled: parent.acts
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
    }

    Text {
        readonly property bool waiting: page.showsAll ? Apps.searching : !Apps.listed

        visible: page.entries.length === 0
        width: page.width
        wrapMode: Text.Wrap
        text: page.problem ? page.problem
            : waiting ? "Looking…"
            : Apps.query ? `No apps match “${Apps.query}”`
            : page.showsAll ? "No apps here" : "No apps installed"
        color: page.problem ? "#b63132" : "#5f6469"
        font { family: Theme.font; pixelSize: 13 }
    }

    DialogButton {
        visible: page.showsAll && Apps.more
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Show more"
        onActivated: Apps.showMore()
    }
}
