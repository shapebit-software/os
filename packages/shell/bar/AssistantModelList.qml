// The models the assistant can answer with, to choose one, in the bubbles
// and the panel (AssistantBubbles.qml, AssistantDock.qml): each with where
// it answers, on this computer or online, and the one in use checked.
// Settings > Assistant > Models adds and removes them.
pragma ComponentBehavior: Bound
import QtQuick
import qs.controls
import qs.services

Column {
    id: list

    signal chosen

    Repeater {
        model: Assistant.models

        Rectangle {
            id: option

            required property var modelData
            readonly property bool current: modelData.id === Assistant.model?.id
            readonly property string where: modelData.where === "local"
                ? (modelData.ready ? "on this computer" : "not downloaded")
                : `${Assistant.providers[modelData.provider]?.name ?? "online"}${modelData.provider === "chatgpt" ? " plan" : ""} · online`

            width: list.width
            height: 30
            color: optionHover.hovered ? Theme.veil(0.07) : "transparent"

            Text {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: `${option.modelData.name} <font color="${Theme.inkFaint}">· ${option.where}</font>`
                color: option.current ? Theme.ink : Theme.inkSoft
                font { family: Theme.font; pixelSize: 12; weight: option.current ? Font.Medium : Font.Normal }
            }
            Icon {
                visible: option.current
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                height: 12
                color: Theme.accent
                strokeWidth: 1.6
                strokes: "M3.5 8.5l3 3 6-7"
            }
            TapHandler {
                onTapped: {
                    if (!option.current)
                        Assistant.chooseModel(option.modelData.id);
                    list.chosen();
                }
            }
            HoverHandler {
                id: optionHover
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
