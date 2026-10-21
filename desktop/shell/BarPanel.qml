// A panel that a bar button opens, hanging below the bar at the right of the
// screen. Escape or a click outside it and the bar closes it.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: panel

    property real panelWidth: 262
    // The space between the panel's right edge and the screen's.
    property real rightInset: Theme.gap
    // Windows besides this one whose clicks do not close it: the bar, so its
    // buttons can switch panels.
    property list<QtObject> grabWindows
    default property alias content: column.data
    property alias spacing: column.spacing
    signal dismissed

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "panel"
    // Not Exclusive: Hyprland then holds back clicks everywhere else, so a
    // click outside could not close the panel. The focus grab gives it the
    // keyboard.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    // The window covers the corner down to the panel; only the panel takes
    // input. The space left of the panel holds its shadow.
    anchors { top: true; right: true }
    implicitWidth: body.x + body.width + rightInset
    implicitHeight: body.y + body.height + shadow.blur + shadow.offset.y
    color: "transparent"
    mask: Region { item: body }

    HyprlandFocusGrab {
        active: panel.visible
        windows: [panel, ...panel.grabWindows]
        onCleared: panel.dismissed()
    }

    RectangularShadow {
        id: shadow
        anchors.fill: body
        offset.y: 14
        blur: 17
        color: Qt.rgba(0.02, 0.05, 0.07, 0.32)
    }

    Rectangle {
        id: body

        x: shadow.blur
        y: Theme.barHeight + Theme.gap
        width: panel.panelWidth
        height: column.implicitHeight + 20
        color: Theme.panel
        border.color: Theme.panelBorder
        focus: true
        Keys.onEscapePressed: panel.dismissed()

        Column {
            id: column
            x: 10
            y: 10
            width: parent.width - 20
            spacing: 8
        }
    }
}
