// The first page: what is about to happen, and the language of the installed system.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import Installer

Step {
    id: page

    // Empty if the backend offers no choice; the image's default then stays.
    readonly property string locale: languages.currentIndex < 0 ? "" : locales[languages.currentIndex]
    readonly property var locales: Backend.capabilities.locales || []

    number: 1
    label: qsTr("Welcome")
    heading: qsTr("Welcome to ShapeBit")
    subtitle: qsTr("A calm, tiled desktop that keeps your windows in order. Setup takes about ten minutes.")
    logoVisible: true
    backVisible: false
    nextText: qsTr("Get started")

    T.ComboBox {
        id: languages
        objectName: "language"
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 6
        implicitWidth: 268
        implicitHeight: 40
        visible: count > 0
        model: page.locales.map(locale => Backend.languageName(locale))
        currentIndex: Math.max(0, page.locales.indexOf("en_US.UTF-8"))

        contentItem: RowLayout {
            spacing: 10
            Mono {
                Layout.leftMargin: 13
                text: qsTr("LANGUAGE")
                font.pixelSize: 9
            }
            Text {
                Layout.fillWidth: true
                text: languages.displayText
                color: Theme.text
                font.pixelSize: Theme.body
                elide: Text.ElideRight
            }
            Text {
                Layout.rightMargin: 13
                text: "⌄"
                color: Theme.muted
                font.pixelSize: Theme.body
            }
        }
        background: Panel {
            border.color: languages.visualFocus || languages.popup.visible ? Theme.accent : Theme.border
        }
        delegate: ListRow {
            required property string modelData
            required property int index
            width: ListView.view.width
            chosen: languages.currentIndex === index
            highlighted: languages.highlightedIndex === index
            contentItem: Text {
                text: modelData
                color: Theme.text
                font.pixelSize: Theme.body
                verticalAlignment: Text.AlignVCenter
            }
        }
        popup: T.Popup {
            y: languages.height + 4
            width: languages.width
            height: Math.min(contentItem.implicitHeight + 2, 240)
            padding: 1
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: languages.delegateModel
                currentIndex: languages.highlightedIndex
                T.ScrollBar.vertical: Bar {}
            }
            background: Panel {}
        }
    }
}
