// A page of Settings for one app (Apps.shown): what it is, what it may reach,
// and installing or removing it. Removing asks first, and keeps the app's data
// unless told otherwise. Its screenshots come from Flathub when this opens.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets

Column {
    id: page

    readonly property var app: Apps.shown
    readonly property var mine: Apps.byId(app.id ?? "")
    readonly property var work: Apps.work[app.id ?? ""] ?? null
    readonly property bool busy: work !== null && !work.error
    // Whether it is asking before removing, and what about the app's data.
    property bool confirming
    property bool deleteData

    spacing: 18

    // It may open asking, from a Remove elsewhere.
    onVisibleChanged: {
        confirming = visible && app.confirming === true;
        deleteData = false;
    }
    // It has gone: there is nothing more to do here.
    onMineChanged: {
        if (!mine)
            confirming = false;
    }

    Item {
        width: page.width
        height: 56

        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 56
            asynchronous: true
            source: page.app.icon ? `file://${page.app.icon}`
                : Quickshell.iconPath(page.app.id ?? "", "application-x-executable")
        }
        Column {
            x: 72
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - actions.width - 16
            spacing: 3

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: page.app.name ?? ""
                color: "#1d2022"
                font { family: Theme.font; pixelSize: 16; weight: Font.DemiBold }
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: page.app.summary ?? ""
                color: "#44484d"
                font { family: Theme.font; pixelSize: 12 }
            }
            Text {
                width: parent.width
                visible: text !== ""
                elide: Text.ElideRight
                text: [page.app.developer, page.app.verified ? "Verified" : "", page.mine?.version, page.mine?.size].filter(t => t).join(" · ")
                color: "#65696f"
                font { family: Theme.font; pixelSize: 11 }
            }
        }
        Row {
            id: actions

            anchors { right: parent.right; verticalCenter: parent.verticalCenter }

            Text {
                visible: page.busy
                text: page.busy ? `${page.work.note}…` : ""
                color: "#65696f"
                font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
            }
            Text {
                visible: !page.busy && (page.app.builtIn === true || (page.mine !== null && !page.mine.removable))
                text: page.app.builtIn ? "Built in" : "For everyone"
                color: "#65696f"
                font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
            }
            DialogButton {
                visible: !page.busy && page.mine !== null && page.mine.removable && !page.confirming
                text: "Remove"
                onActivated: page.confirming = true
            }
            DialogButton {
                visible: !page.busy && page.mine === null && Apps.listed && Apps.installedError === ""
                strong: true
                text: "Install"
                onActivated: Apps.install(page.app.id)
            }
        }
    }

    Text {
        visible: page.work?.error !== undefined
        width: page.width
        wrapMode: Text.Wrap
        text: `Couldn't ${page.work?.action ?? "do that"}: ${page.work?.error ?? ""}`
        color: "#b63132"
        font { family: Theme.font; pixelSize: 12 }
    }

    // Asking before removing.
    Rectangle {
        visible: page.confirming && !page.busy && page.mine !== null
        width: page.width
        height: asking.height + 28
        color: "white"
        border.color: "#d8dbde"

        Column {
            id: asking

            x: 16
            y: 14
            width: parent.width - 32
            spacing: 12

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: `Remove ${page.app.name ?? "this app"}?`
                    + (page.mine?.browser ? " It's your default browser, so links won't open until you choose another." : "")
                color: "#1d2022"
                font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
            }
            Item {
                width: parent.width
                height: 34

                Switch {
                    id: dataSwitch
                    anchors.verticalCenter: parent.verticalCenter
                    on: page.deleteData
                    offColor: "#d5d8db"
                    onToggled: page.deleteData = !page.deleteData
                }
                Text {
                    anchors { left: dataSwitch.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: "Also delete its data and settings"
                    color: "#44484d"
                    font { family: Theme.font; pixelSize: 12 }
                }
                Row {
                    anchors.right: parent.right
                    spacing: 8

                    DialogButton {
                        text: "Cancel"
                        onActivated: page.confirming = false
                    }
                    DialogButton {
                        strong: true
                        text: "Remove"
                        onActivated: {
                            Apps.remove(page.app.id, page.deleteData);
                            page.confirming = false;
                            page.deleteData = false;
                        }
                    }
                }
            }
        }
    }

    // The screenshots.
    Flickable {
        visible: (page.app.screenshots?.length ?? 0) > 0
        width: page.width
        height: 220
        contentWidth: shots.width
        clip: true

        Row {
            id: shots

            spacing: 10

            Repeater {
                model: page.visible ? page.app.screenshots ?? [] : []

                Image {
                    required property string modelData

                    height: 220
                    width: status === Image.Ready ? implicitWidth * height / implicitHeight : 340
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize.height: 440
                    source: modelData
                }
            }
        }
    }

    Text {
        visible: text !== ""
        width: page.width
        wrapMode: Text.Wrap
        text: page.app.description ?? ""
        rightPadding: Math.max(0, page.width - 720)
        color: "#1d2022"
        lineHeight: 1.2
        font { family: Theme.font; pixelSize: 13 }
    }

    // What it may reach, and where it comes from.
    Rectangle {
        visible: !page.app.builtIn
        width: page.width
        height: facts.height + 2
        color: "white"
        border.color: "#d8dbde"

        Column {
            id: facts

            x: 1
            y: 1
            width: parent.width - 2

            Repeater {
                model: [
                    ["Can reach", page.shownPermissions()],
                    ...(page.app.license ? [["License", page.app.license]] : []),
                    ...(page.app.homepage ? [["Website", page.app.homepage]] : []),
                ]

                Item {
                    id: fact

                    required property var modelData
                    required property int index

                    width: facts.width
                    height: value.height + 24

                    Rectangle {
                        visible: fact.index > 0
                        width: parent.width
                        height: 1
                        color: "#e6e8ea"
                    }
                    Text {
                        x: 16
                        y: 12
                        text: fact.modelData[0]
                        color: "#1d2022"
                        font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                    }
                    Text {
                        id: value

                        x: 120
                        y: 12
                        width: parent.width - x - 16
                        wrapMode: Text.Wrap
                        text: fact.modelData[1]
                        color: "#44484d"
                        font { family: Theme.font; pixelSize: 12 }
                    }
                }
            }
        }
    }

    function shownPermissions(): string {
        const permissions = app.permissions;
        if (permissions === undefined)
            return "Checking…";
        if (permissions === null)
            return "Couldn't be checked";
        return permissions.length ? permissions.join(", ") : "Nothing beyond its own window";
    }
}
