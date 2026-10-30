// A panel that opens beside what opened it (Shell.qml), off the bar that is
// on: below a bar at the top, above one at the bottom, beside one on a side,
// centered on the button as far as the screen allows. The window covers the
// screen; only the panel takes input. Escape or a click outside the panel and
// the bars closes it.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: popout

    // The panel's name in Shell.panel, and its screen's.
    required property string name
    required property string screenName
    // What the panel holds; the panel is as large as it.
    default property alias content: body.data
    readonly property Item body: body
    signal dismissed

    // How far the panel is from the bar and from the screen's edges.
    property real margin: Theme.gap
    // An arrow from the panel to what opened it, in the panel's colors: those
    // of PopoverFrame unless set.
    property bool arrow: true
    property color arrowColor: edge === "Top" ? Theme.popoverTop : Theme.popoverBottom
    property color arrowBorder: Theme.popoverRing
    // Whether the panel stands on its own near the top of the screen,
    // centered, rather than beside what opened it.
    property bool floating
    // Whether the panel opens over the middle of what opened it, such as a
    // window, with no arrow.
    property bool centered
    readonly property rect anchor: Shell.anchor
    readonly property string edge: Shell.edge

    visible: Shell.isOpen(name, screenName)
    onDismissed: Shell.close()

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "panel"
    // Not Exclusive: Hyprland then holds back clicks everywhere else, so a
    // click outside could not close the panel. The focus grab gives it the
    // keyboard.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region { item: body }

    HyprlandFocusGrab {
        active: popout.visible
        windows: [popout, ...Shell.bars]
        onCleared: popout.dismissed()
    }

    Item {
        id: body

        function clamp(at: real, size: real, length: real): real {
            return Math.max(popout.margin, Math.min(length - popout.margin - size, at - size / 2));
        }

        x: popout.floating ? (popout.width - width) / 2
            : popout.centered ? clamp(popout.anchor.x + popout.anchor.width / 2, width, popout.width)
            : popout.edge === "Left" ? Shell.depth + popout.margin
            : popout.edge === "Right" ? popout.width - Shell.depth - popout.margin - width
            : clamp(popout.anchor.x + popout.anchor.width / 2, width, popout.width)
        y: popout.floating ? Theme.barHeight + popout.margin + popout.height * 0.12
            : popout.centered ? clamp(popout.anchor.y + popout.anchor.height / 2, height, popout.height)
            : popout.edge === "Top" ? Shell.depth + popout.margin
            : popout.edge === "Bottom" ? popout.height - Shell.depth - popout.margin - height
            : clamp(popout.anchor.y + popout.anchor.height / 2, height, popout.height)
        width: childrenRect.width
        height: childrenRect.height
        focus: true
        Keys.onEscapePressed: popout.dismissed()
    }

    // The arrow: drawn pointing down from the panel's bottom, and turned for
    // the other edges, at what opened the panel as far as the panel reaches.
    Item {
        readonly property bool across: popout.edge === "Top" || popout.edge === "Bottom"
        readonly property real centerX: popout.edge === "Left" ? body.x - 3.5
            : popout.edge === "Right" ? body.x + body.width + 3.5
            : Math.max(body.x + 10, Math.min(body.x + body.width - 10, popout.anchor.x + popout.anchor.width / 2))
        readonly property real centerY: popout.edge === "Top" ? body.y - 3.5
            : popout.edge === "Bottom" ? body.y + body.height + 3.5
            : Math.max(body.y + 10, Math.min(body.y + body.height - 10, popout.anchor.y + popout.anchor.height / 2))

        visible: popout.arrow && !popout.floating && !popout.centered
        x: centerX - width / 2
        y: centerY - height / 2
        width: 18
        height: 9
        rotation: ({ "Bottom": 0, "Top": 180, "Left": 90, "Right": -90 })[popout.edge] ?? 0
        clip: true

        Rectangle {
            x: 9 - width / 2
            y: -width / 2
            width: 12.7
            height: 12.7
            rotation: 45
            color: popout.arrowColor
            border.color: popout.arrowBorder
        }
    }
}
