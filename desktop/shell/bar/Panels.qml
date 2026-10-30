// The panels of one screen (Popout.qml); Shell.panel says which one is open.
import QtQuick
import Quickshell
import qs.services
import qs.windows

Scope {
    id: panels

    required property ShellScreen modelData

    // The icons of the sound devices, as on their buttons (ShellItem.qml).
    readonly property string microphone: "M5.6 4.2a2.4 2.4 0 0 1 4.8 0v3.2a2.4 2.4 0 0 1-4.8 0z"
        + "M3.4 7.6a4.6 4.6 0 0 0 9.2 0M8 12.2v2"
    readonly property string speaker: "M10.8 5.9a3 3 0 0 1 0 4.2M12.7 4.2a5.6 5.6 0 0 1 0 7.6"
    readonly property string speakerBody: "M3 6.2h2.2L8.6 3.4v9.2L5.2 9.8H3z"

    VolumePanel {
        screen: panels.modelData
        screenName: panels.modelData?.name ?? ""
        name: "microphone"
        node: Audio.input
        strokes: panels.microphone
        mutedStroke: "M2.5 2.5l11 11"
    }
    VolumePanel {
        screen: panels.modelData
        screenName: panels.modelData?.name ?? ""
        name: "sound"
        node: Audio.output
        strokes: panels.speaker
        fills: panels.speakerBody
        mutedStroke: "M10.6 6l4 4M14.6 6l-4 4"
        wavesWhenMuted: false
    }
    NotificationsPanel {
        screen: panels.modelData
        screenName: panels.modelData?.name ?? ""
        name: "notifications"
    }
    BrightnessPanel {
        screen: panels.modelData
        screenName: panels.modelData?.name ?? ""
        name: "brightness"
    }
    BatteryPanel {
        screen: panels.modelData
        screenName: panels.modelData?.name ?? ""
        name: "battery"
    }
    NetworkPanel {
        screen: panels.modelData
        screenName: panels.modelData?.name ?? ""
        name: "network"
    }
    LanguagePanel {
        screen: panels.modelData
        screenName: panels.modelData?.name ?? ""
        name: "language"
    }
    AccountPanel {
        screen: panels.modelData
        screenName: panels.modelData?.name ?? ""
        name: "account"
    }
    AppsPanel {
        screen: panels.modelData
        screenName: panels.modelData?.name ?? ""
    }
    AssistantPanel {
        screen: panels.modelData
        screenName: panels.modelData?.name ?? ""
    }
    LayoutMenu {
        screen: panels.modelData
        screenName: panels.modelData?.name ?? ""
    }
    WindowMenu {
        screen: panels.modelData
        screenName: panels.modelData?.name ?? ""
    }
}
