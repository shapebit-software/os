// Apps, as in the demo: the installed applications beside the Apps button, a
// row of ten to a page, with a search field and the pages' arrows and marks. A click, or Enter for the first match, opens an
// application on the current workspace; dragged to a map in the strip, it
// opens there. Escape or a click elsewhere closes it.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets

Popout {
    id: panel

    readonly property int perPage: 10
    readonly property list<DesktopEntry> apps: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))
    readonly property list<DesktopEntry> results: {
        const query = search.text.trim().toLowerCase();
        return query ? apps.filter(a => a.name.toLowerCase().includes(query)) : apps;
    }
    readonly property int pages: Math.max(1, Math.ceil(results.length / perPage))
    property int page
    readonly property int shownPage: Math.min(page, pages - 1)

    function launch(app: DesktopEntry) {
        app.execute();
        dismissed();
    }

    name: "apps"

    onVisibleChanged: {
        search.text = "";
        page = 0;
        if (visible)
            search.forceActiveFocus();
    }

    // As wide as the demo's, or as the screen allows.
    readonly property real frameWidth: Math.min(720, width - 2 * Theme.gap - 12)

    function step(by: int) {
        page = Math.max(0, Math.min(pages - 1, shownPage + by));
    }

    PopoverFrame {
        padding: 0

        Column {
            width: panel.frameWidth

            // The search field, and the pages.
            Item {
                width: parent.width
                height: 46

                Rectangle {
                    x: 12
                    y: 12
                    width: Math.min(320, parent.width - pager.width - 40)
                    height: 32
                    color: Theme.veil(0.06)

                    Icon {
                        x: 11
                        anchors.verticalCenter: parent.verticalCenter
                        height: 13
                        strokeWidth: 1.5
                        capStyle: ShapePath.RoundCap
                        color: Theme.inkFaint
                        strokes: "M2.4 7a4.6 4.6 0 1 0 9.2 0a4.6 4.6 0 1 0-9.2 0zM10.4 10.4L14 14"
                    }
                    TextInput {
                        id: search

                        anchors { left: parent.left; right: parent.right; leftMargin: 33; rightMargin: 10 }
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.ink
                        selectionColor: Theme.accent
                        font { family: Theme.font; pixelSize: 13 }
                        clip: true
                        onTextChanged: panel.page = 0

                        Keys.onEscapePressed: panel.dismissed()
                        Keys.onReturnPressed: {
                            if (panel.results.length)
                                panel.launch(panel.results[0]);
                        }

                        Text {
                            visible: !search.text
                            text: "Search apps"
                            color: Theme.inkFaint
                            font: search.font
                        }
                    }
                }

                Row {
                    id: pager

                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    y: 14
                    spacing: 8

                    component Arrow: Rectangle {
                        id: arrow

                        property string strokes
                        property bool enabled_
                        signal clicked

                        width: 28
                        height: 28
                        color: arrowHover.hovered && enabled_ ? Theme.veil(0.07) : "transparent"
                        opacity: enabled_ ? 1 : 0.3

                        Icon {
                            anchors.centerIn: parent
                            height: 10
                            strokeWidth: 2
                            capStyle: ShapePath.SquareCap
                            color: Theme.ink
                            strokes: arrow.strokes
                        }
                        TapHandler {
                            onTapped: arrow.clicked()
                        }
                        HoverHandler {
                            id: arrowHover
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    Arrow {
                        strokes: "M10 3L5 8l5 5"
                        enabled_: panel.shownPage > 0
                        onClicked: panel.step(-1)
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Repeater {
                            model: panel.pages

                            Rectangle {
                                required property int index

                                width: index === panel.shownPage ? 18 : 10
                                height: 3
                                color: index === panel.shownPage ? Theme.accent : Theme.veil(0.2)

                                Behavior on width { NumberAnimation { duration: 160 } }

                                TapHandler {
                                    onTapped: panel.page = parent.index
                                }
                            }
                        }
                    }
                    Arrow {
                        strokes: "M6 3l5 5-5 5"
                        enabled_: panel.shownPage < panel.pages - 1
                        onClicked: panel.step(1)
                    }
                }
            }

            // The page of applications.
            Item {
                visible: panel.results.length > 0
                width: parent.width
                height: 106

                Row {
                    id: row

                    x: 8
                    y: 10
                    spacing: 2

                    Repeater {
                        model: panel.results.slice(panel.shownPage * panel.perPage,
                            (panel.shownPage + 1) * panel.perPage)

                        Rectangle {
                            id: app

                            required property DesktopEntry modelData

                            width: (panel.frameWidth - 16 - 9 * row.spacing) / 10
                            height: 86
                            color: appHover.hovered ? Theme.veil(0.07) : "transparent"

                            IconImage {
                                y: 10
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitSize: 38
                                source: Quickshell.iconPath(app.modelData.icon, "application-x-executable")
                            }
                            Text {
                                y: 55
                                x: 4
                                width: parent.width - 8
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: app.modelData.name
                                color: Theme.ink
                                font { family: Theme.font; pixelSize: 11; weight: Font.Medium }
                            }

                            Drag.dragType: Drag.Automatic
                            Drag.supportedActions: Qt.CopyAction
                            Drag.imageSource: Quickshell.iconPath(app.modelData.icon, "application-x-executable")
                            Drag.imageSourceSize: Qt.size(38, 38)
                            Drag.onDragFinished: Dragging.clear()

                            TapHandler {
                                onTapped: panel.launch(app.modelData)
                            }
                            // Dragged to a map on the dock, the application
                            // opens there (WorkspaceMap.qml).
                            DragHandler {
                                target: null
                                onActiveChanged: {
                                    if (active) {
                                        Dragging.app = app.modelData;
                                        app.Drag.active = true;
                                    }
                                }
                            }
                            HoverHandler {
                                id: appHover
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }

                WheelHandler {
                    property real lastStep

                    onWheel: event => {
                        const now = Date.now();
                        const delta = event.angleDelta.y || event.angleDelta.x;
                        if (now - lastStep < 350 || Math.abs(delta) < 8)
                            return;
                        lastStep = now;
                        panel.step(delta < 0 ? 1 : -1);
                    }
                }
            }

            Text {
                visible: panel.results.length === 0
                width: parent.width
                topPadding: 18
                bottomPadding: 22
                horizontalAlignment: Text.AlignHCenter
                text: `No apps match “${search.text.trim()}”`
                color: Theme.inkFaint
                font { family: Theme.font; pixelSize: 12 }
            }
        }
    }
}
