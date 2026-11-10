// Settings > Downloads: everything in the one queue (Downloads.qml), apps,
// browsers, extras, and the daily app updates alike: what is under way first, with how far it is,
// then what ended, newest first. Each can be cancelled while it waits or
// works, and tried again once it failed or was cancelled.
pragma ComponentBehavior: Bound
import QtQuick
import qs.controls
import qs.services

Column {
    id: page

    readonly property var shown: [
        ...Downloads.jobs.filter(j => j.state === "running"),
        ...Downloads.jobs.filter(j => j.state === "queued"),
        ...Downloads.jobs.filter(j => !["queued", "running"].includes(j.state)).reverse(),
    ]

    spacing: 16

    function kindOf(job: var): string {
        if (job.kind === "extra")
            return job.action === "remove" ? "Optional download · removing" : "Optional download";
        if (job.kind === "browser")
            return "Browser";
        if (job.kind === "update")
            return "Every app";
        return job.action === "remove" ? "App · removing" : "App";
    }

    Item {
        width: page.width
        height: 30

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Downloads.busy ? "It goes on if you close Settings, and after you sign in again."
                : "What the desktop downloads and installs shows here."
            color: Theme.textMuted
            font { family: Theme.font; pixelSize: 12 }
        }
        DialogButton {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: Downloads.anyEnded
            text: "Clear finished"
            onActivated: Downloads.clear()
        }
    }

    Text {
        visible: page.shown.length === 0
        text: "Nothing is downloading or installing."
        color: Theme.textMuted
        font { family: Theme.font; pixelSize: 13 }
    }

    Rectangle {
        visible: page.shown.length > 0
        width: page.width
        height: list.height + 2
        color: Theme.surface
        border.color: Theme.line

        Column {
            id: list

            x: 1
            y: 1
            width: parent.width - 2

            Repeater {
                model: page.shown

                Column {
                    id: job

                    required property var modelData
                    required property int index
                    readonly property bool active: ["queued", "running"].includes(modelData.state)
                    readonly property bool again: ["failed", "cancelled"].includes(modelData.state)

                    width: list.width

                    Rectangle {
                        visible: job.index > 0
                        width: parent.width
                        height: 1
                        color: Theme.lineSoft
                    }
                    Item {
                        width: parent.width
                        height: 64

                        Column {
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 32 - actions.width
                            spacing: 3

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: job.modelData.name
                                color: Theme.textStrong
                                font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: `${page.kindOf(job.modelData)} · ${Downloads.describe(job.modelData)}`
                                color: job.modelData.state === "failed" ? Theme.dangerInk : Theme.textMuted
                                font { family: Theme.font; pixelSize: 11 }
                            }
                            Rectangle {
                                visible: job.modelData.state === "running"
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Theme.lineSoft

                                Rectangle {
                                    width: parent.width * job.modelData.percent / 100
                                    height: parent.height
                                    radius: 2
                                    color: Theme.accent
                                }
                            }
                        }
                        Row {
                            id: actions

                            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            spacing: 8

                            DialogButton {
                                visible: job.active && !job.modelData.cancel
                                text: "Cancel"
                                onActivated: Downloads.cancel([job.modelData.key])
                            }
                            DialogButton {
                                visible: job.again
                                text: "Try again"
                                onActivated: Downloads.retry(job.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
