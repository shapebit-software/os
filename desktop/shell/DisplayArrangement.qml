// The displays in Settings > Display as they stand beside each other: drag
// one into place, where it snaps against the edge of another (Displays.snap),
// or click it to change it with the settings below. The primary display has
// a bar along its top, and a display that others mirror names them.
pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: arrangement

    // The display the settings below change, by name.
    property string selected
    signal picked(name: string)

    // Where the displays show: the top left of their bounds, how many pixels
    // here a pixel there takes, and where the bounds start here, centered,
    // with room around them to drag a display to any side. It holds while a
    // display is dragged, so that the others stay put.
    readonly property var live: {
        const shown = Displays.arranged;
        const left = Math.min(...shown.map(d => d.x)), top = Math.min(...shown.map(d => d.y));
        const w = Math.max(...shown.map(d => d.x + d.w)) - left, h = Math.max(...shown.map(d => d.y + d.h)) - top;
        const room = shown.length > 1 ? 1 : 0;
        const fit = Math.min((width - 32) / (w + room * Math.max(...shown.map(d => d.w))),
            (height - 32) / (h + room * Math.max(...shown.map(d => d.h))));
        return { left, top, fit, x: (width - w * fit) / 2, y: (height - h * fit) / 2 };
    }
    property var held: null
    readonly property var frame: held ?? live

    height: 200
    clip: true
    color: "#eef0f2"
    border.color: "#e1e3e6"

    // A new list from the compositor: the drag has landed.
    Connections {
        target: Displays

        function onAllChanged() {
            arrangement.held = null;
        }
    }

    Repeater {
        model: Displays.arranged

        Rectangle {
            id: tile

            required property var modelData
            readonly property bool current: arrangement.selected === modelData.name
            readonly property bool primary: Displays.primary === modelData.name && Displays.arranged.length > 1
            readonly property var mirrors: Displays.all.filter(d => d.mirrorOf === modelData.name)
            // Where it is dragged to, snapped, in the compositor's coordinates.
            property var at: null
            readonly property var place: at ?? modelData

            x: arrangement.frame.x + (place.x - arrangement.frame.left) * arrangement.frame.fit
            y: arrangement.frame.y + (place.y - arrangement.frame.top) * arrangement.frame.fit
            z: at ? 1 : 0
            width: modelData.w * arrangement.frame.fit
            height: modelData.h * arrangement.frame.fit
            color: current ? Theme.accentSoft : "white"
            border.width: current ? 2 : 1
            border.color: current ? Theme.accent : "#c3c7cb"

            Rectangle {
                visible: tile.primary
                x: tile.border.width
                y: tile.border.width
                width: tile.width - 2 * x
                height: 5
                color: tile.current ? Theme.accent : "#5f6469"
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - 16
                spacing: 2

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: tile.modelData.label
                    color: "#1d2022"
                    font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: [tile.primary ? "Primary" : "", tile.mirrors.length ? `Also on ${tile.mirrors.map(d => d.label).join(", ")}` : ""]
                        .filter(t => t).join(" · ")
                    color: "#5f6469"
                    font { family: Theme.font; pixelSize: 11 }
                }
            }

            MouseArea {
                property point from
                property bool moved

                anchors.fill: parent
                // Settings scrolls otherwise.
                preventStealing: true
                enabled: Displays.arranged.length > 1 || !tile.current
                cursorShape: tile.at ? Qt.ClosedHandCursor : Displays.arranged.length > 1 ? Qt.OpenHandCursor : Qt.PointingHandCursor
                onPressed: mouse => {
                    from = mapToItem(arrangement, mouse.x, mouse.y);
                    moved = false;
                }
                onPositionChanged: mouse => {
                    const now = mapToItem(arrangement, mouse.x, mouse.y);
                    if (!moved && Math.hypot(now.x - from.x, now.y - from.y) < 4 || Displays.arranged.length < 2)
                        return;
                    moved = true;
                    arrangement.held = arrangement.frame;
                    const fit = arrangement.frame.fit;
                    const d = tile.modelData;
                    tile.at = Displays.snap(d.name, d.x + (now.x - from.x) / fit, d.y + (now.y - from.y) / fit, d.w, d.h, 14 / fit) ?? tile.at;
                }
                onReleased: {
                    if (!moved)
                        arrangement.picked(tile.modelData.name);
                    else if (tile.at && (tile.at.x !== tile.modelData.x || tile.at.y !== tile.modelData.y))
                        Displays.move(tile.modelData.name, tile.at.x, tile.at.y);
                    else {
                        tile.at = null;
                        arrangement.held = null;
                    }
                }
            }
        }
    }
}
