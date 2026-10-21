// What Tabs and Accordion draw besides the window they show (compositor/
// layouts.lua leaves room for it): Tabs a tab bar above it, a tab for each
// window; Accordion a folded strip beside it for each other window, with its
// icon and name. A click on a tab or a strip shows that window; under the
// pointer, a tab also shows buttons to maximize and to close its window.
// Windows cover the surface, which sits under them.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: surface

    required property ShellScreen modelData

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
    readonly property HyprlandWorkspace workspace: monitor?.activeWorkspace ?? null
    readonly property string layout: workspace ? Compositor.layoutOf(workspace.id) : ""
    readonly property var tiles: workspace ? Compositor.tiles[workspace.id] ?? null : null
    // The workspace's windows in order, and the one shown.
    readonly property list<HyprlandToplevel> windows: {
        const all = workspace?.toplevels.values ?? [];
        return (tiles?.order ?? []).map(address => all.find(w => w.address === address)).filter(w => w);
    }
    readonly property string shown: tiles?.shown ?? ""
    readonly property bool active: windows.length > 0 && (layout === "tabs" || layout === "accordion")

    // The area the compositor tiles, on this window.
    readonly property var reserved: monitor?.lastIpcObject.reserved ?? [0, 0, 0, 0]
    readonly property real areaX: reserved[0] + Theme.gap
    readonly property real areaY: reserved[1] + Theme.gap
    readonly property real areaWidth: width - reserved[0] - reserved[2] - 2 * Theme.gap
    readonly property real areaHeight: height - reserved[1] - reserved[3] - 2 * Theme.gap

    // A window's application, looked up again when the applications change.
    function entryOf(window: HyprlandToplevel): DesktopEntry {
        void DesktopEntries.applications.values;
        const cls = window?.lastIpcObject.class;
        return cls ? DesktopEntries.heuristicLookup(cls) : null;
    }
    function nameOf(window: HyprlandToplevel): string {
        return entryOf(window)?.name ?? window?.title ?? "";
    }
    function iconOf(window: HyprlandToplevel): string {
        return Quickshell.iconPath(entryOf(window)?.icon ?? "", "application-x-executable");
    }

    screen: modelData
    visible: active
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "tabs"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region {
        Region { item: tabBar }
        Region { item: strips }
    }

    // Tabs: the tab bar.
    Row {
        id: tabBar

        readonly property real tabWidth: Math.min(220, (surface.areaWidth - spacing * (surface.windows.length - 1)) / surface.windows.length)

        visible: surface.layout === "tabs"
        x: surface.areaX
        y: surface.areaY
        height: 30
        spacing: 2

        Repeater {
            model: tabBar.visible ? surface.windows : []

            Rectangle {
                id: tab

                required property HyprlandToplevel modelData
                readonly property bool shown: modelData.address === surface.shown

                width: tabBar.tabWidth
                height: tabBar.height
                color: Qt.rgba(1, 1, 1, shown ? 0.3 : 0.12)
                border.color: Qt.rgba(1, 1, 1, 0.14)

                HoverHandler { id: tabHover }
                TapHandler {
                    onTapped: Compositor.focusWindow(tab.modelData.address)
                }

                IconImage {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 13
                    source: surface.iconOf(tab.modelData)
                }
                Text {
                    x: 31
                    anchors.verticalCenter: parent.verticalCenter
                    width: (buttons.visible ? buttons.x : parent.width) - x - 4
                    elide: Text.ElideRight
                    text: surface.nameOf(tab.modelData)
                    color: tab.shown ? "#fafbfc" : Qt.rgba(0.9, 0.91, 0.93, 0.75)
                    font { family: Theme.font; pixelSize: 11; weight: Font.Bold }
                }

                Row {
                    id: buttons

                    visible: tabHover.hovered
                    anchors.right: parent.right

                    TabButton {
                        hoverColor: "#f2c133"
                        strokes: "M1 3.5V1h2.5M6.5 1H9v2.5M9 6.5V9H6.5M3.5 9H1V6.5"
                        onClicked: Compositor.toggleMaximized(tab.modelData.address)
                    }
                    TabButton {
                        hoverColor: Theme.dangerFill
                        strokes: "M1.5 1.5l6 6M7.5 1.5l-6 6"
                        onClicked: Compositor.closeWindow(tab.modelData.address)
                    }
                }
            }
        }
    }

    // Accordion: a strip for each folded window, the shown one leaving room
    // for itself between them.
    Item {
        id: strips

        readonly property int folded: 34

        visible: surface.layout === "accordion"
        x: surface.areaX
        y: surface.areaY
        width: surface.areaWidth
        height: surface.areaHeight

        Repeater {
            model: strips.visible ? surface.windows : []

            Rectangle {
                id: strip

                required property HyprlandToplevel modelData
                required property int index
                readonly property int shownIndex: surface.windows.findIndex(w => w.address === surface.shown)

                visible: modelData.address !== surface.shown
                x: index < shownIndex ? index * (strips.folded + Theme.gap)
                    : strips.width - (surface.windows.length - index) * (strips.folded + Theme.gap) + Theme.gap
                width: strips.folded
                height: strips.height
                color: Qt.rgba(1, 1, 1, 0.12)

                // A light left edge and a dark right one, as in the demo.
                Rectangle {
                    width: 1
                    height: parent.height
                    color: Qt.rgba(1, 1, 1, 0.5)
                }
                Rectangle {
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: Qt.rgba(0.1, 0.1, 0.12, 0.08)
                }

                IconImage {
                    y: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitSize: 13
                    source: surface.iconOf(strip.modelData)
                }
                // The name reads down the strip.
                Text {
                    x: (parent.width + height) / 2
                    y: 33
                    width: parent.height - 43
                    rotation: 90
                    transformOrigin: Item.TopLeft
                    elide: Text.ElideRight
                    text: surface.nameOf(strip.modelData)
                    color: Qt.rgba(0.9, 0.91, 0.93, 0.75)
                    font { family: Theme.font; pixelSize: 11; weight: Font.Bold }
                }

                TapHandler {
                    onTapped: Compositor.focusWindow(strip.modelData.address)
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    // A button on a tab, 30 square, colored under the pointer.
    component TabButton: Rectangle {
        id: button

        property color hoverColor
        property string strokes
        signal clicked

        width: 30
        height: 30
        color: buttonHover.hovered ? hoverColor : "transparent"

        Icon {
            anchors.centerIn: parent
            height: 10
            gridWidth: 10
            gridHeight: 10
            strokeWidth: 1.4
            strokes: button.strokes
            color: "#fafbfc"
        }

        HoverHandler {
            id: buttonHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: button.clicked()
        }
    }
}
