// Apps: the installed applications beside the Apps button, twelve to a page,
// with a search field. A click, or Enter for the first match, opens an
// application on the current workspace; dragged to a map in the strip, it
// opens there. Escape or a click elsewhere closes it.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

Popout {
    id: panel

    readonly property int perPage: 12
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
    // The compositor blurs behind this namespace (compositor/hyprland.lua).
    WlrLayershell.namespace: "apps"

    onVisibleChanged: {
        search.text = "";
        page = 0;
        if (visible)
            search.forceActiveFocus();
    }

    Rectangle {
        id: frame

        width: 372
        height: implicitHeight
        implicitHeight: column.implicitHeight + 2
        color: Qt.rgba(0.153, 0.157, 0.188, 0.97)
        border.color: Theme.panelBorder

        Column {
            id: column

            x: 1
            y: 1
            width: parent.width - 2

            // The search field.
            Item {
                width: parent.width
                height: 52

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#121212"
                    border.color: Theme.panelBorder

                    Icon {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13
                        height: 13
                        strokes: "M2.4 7a4.6 4.6 0 1 0 9.2 0a4.6 4.6 0 1 0-9.2 0zM10.4 10.4L14 14"
                        color: "#bbbec1"
                        capStyle: ShapePath.RoundCap
                    }

                    TextInput {
                        id: search

                        anchors { left: parent.left; right: parent.right; leftMargin: 31; rightMargin: 10 }
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
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
                            color: "#bbbec1"
                            font: search.font
                        }
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: "#232426"
                }
            }

            // The page of applications; the page keeps its height while a
            // search narrows it.
            Item {
                width: parent.width
                height: 288

                Grid {
                    id: grid

                    padding: 6
                    columns: 4
                    spacing: 2

                    Repeater {
                        model: panel.results.slice(panel.shownPage * panel.perPage,
                            (panel.shownPage + 1) * panel.perPage)

                        Rectangle {
                            id: app

                            required property DesktopEntry modelData

                            width: (column.width - 2 * grid.padding - 3 * grid.spacing) / 4
                            height: 90
                            color: appHover.hovered ? "#35383e" : "transparent"

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
                                color: "#f3f5f8"
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
                            // Dragged to a map in the strip, the application
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
                        panel.page = Math.max(0, Math.min(panel.pages - 1, panel.shownPage + (delta < 0 ? 1 : -1)));
                    }
                }
            }

            Text {
                id: none

                visible: panel.results.length === 0
                width: parent.width
                topPadding: 18
                bottomPadding: 22
                horizontalAlignment: Text.AlignHCenter
                text: `No apps match “${search.text.trim()}”`
                color: "#acb2b7"
                font { family: Theme.font; pixelSize: 12 }
            }

            // The page dots, when there is more than one page.
            Row {
                visible: panel.pages > 1
                height: 34
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Repeater {
                    model: panel.pages

                    Rectangle {
                        required property int index

                        anchors.verticalCenter: parent.verticalCenter
                        width: index === panel.shownPage ? 18 : 6
                        height: 6
                        radius: 3
                        color: "#f0f2f4"
                        opacity: index === panel.shownPage ? 1 : 0.35

                        Behavior on width { NumberAnimation { duration: 160 } }

                        TapHandler {
                            onTapped: panel.page = parent.index
                        }
                    }
                }
            }
        }
    }
}
