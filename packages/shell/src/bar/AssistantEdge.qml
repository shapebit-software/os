// The right edge of the screen opens the assistant's panel
// (AssistantDock.qml): the pointer pushed against the middle of the edge for
// a moment, so that passing by, or reaching for a scroll bar, opens nothing;
// nor does a pointer that was resting there when the panel hid.
// Not with a bar on that edge, which is then the bar's; and Settings >
// Assistant turns it off.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

PanelWindow {
    id: edge

    required property ShellScreen modelData

    screen: modelData
    visible: Settings.assistantEdge && Assistant.panelOn === "" && !Lock.locked
        && Settings.systemBar !== "Right" && Settings.dock !== "Right"
    color: "transparent"
    // The middle third of the edge: anchored at the right only, it is
    // centered along it.
    anchors.right: true
    implicitWidth: 2
    implicitHeight: (modelData?.height ?? 0) / 3
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "assistant-edge"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // A pointer already resting on the edge when the panel hides opens
    // nothing: it has to leave and come back.
    property bool armed
    onVisibleChanged: {
        armed = false;
        settle.restart();
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (!hovered)
                edge.armed = true;
        }
    }
    Timer {
        id: settle
        interval: 150
        onTriggered: edge.armed = edge.armed || !hover.hovered
    }
    Timer {
        running: hover.hovered && edge.armed
        interval: 300
        onTriggered: Assistant.openPanel(edge.modelData.name)
    }
}
