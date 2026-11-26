// The wallpaper of one screen, below every window.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    required property ShellScreen modelData

    screen: modelData
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "wallpaper"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    Backdrop { anchors.fill: parent }
}
