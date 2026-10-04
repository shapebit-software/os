// The layout every page shares: a centered heading and subtitle, the page's
// content, and the Back and Next buttons below it.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// A focus scope, so that a page's first field gets the focus with the page.
FocusScope {
    id: step

    focus: true

    // Where the page is in the setup, shown in the window's header.
    property int number: 1
    property string label

    property string heading
    property string subtitle
    property bool logoVisible: false
    property int contentWidth: 470

    property string nextText: qsTr("Continue")
    property string nextKind: "primary"
    property bool nextEnabled: true
    property bool nextVisible: true
    property bool backVisible: true
    default property alias content: body.data

    signal next()
    signal back()

    StackView.onActivated: forceActiveFocus()

    // Enter goes on, from wherever the focus is in the page, except where
    // going on erases a disk: that takes a deliberate click or Space.
    function enter() {
        if (nextVisible && nextEnabled && nextKind === "primary")
            next()
    }
    Keys.onReturnPressed: enter()
    Keys.onEnterPressed: enter()

    ColumnLayout {
        anchors.centerIn: parent
        // Wide enough for the heading and subtitle of every page.
        width: Math.max(step.contentWidth, 470)
        spacing: 0

        Logo {
            visible: step.logoVisible
            size: 46
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 26
        }
        Text {
            objectName: "heading"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: step.heading
            color: Theme.text
            font.pixelSize: step.logoVisible ? 40 : 28
            font.weight: Font.DemiBold
            font.letterSpacing: -0.5
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 6
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: step.subtitle
            color: Theme.muted
            font.pixelSize: step.logoVisible ? 15 : 13
            lineHeight: 1.3
        }
        ColumnLayout {
            id: body
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: step.contentWidth
            Layout.maximumWidth: step.contentWidth
            Layout.topMargin: 22
            spacing: 12
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 24
            spacing: 10

            Btn {
                objectName: "back"
                kind: "secondary"
                text: qsTr("Back")
                visible: step.backVisible
                onClicked: step.back()
            }
            Btn {
                objectName: "next"
                kind: step.nextKind
                text: step.nextText
                visible: step.nextVisible
                enabled: step.nextEnabled
                onClicked: step.next()
            }
        }
    }
}
