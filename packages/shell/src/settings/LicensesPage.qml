// Settings > Licenses: each component's license texts under /usr/share/licenses,
// the optional models' included, read through licenses/src/licenses and shown verbatim.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.controls
import qs.services

Column {
    id: page

    property var components: []
    // The component whose files are listed, and the file that is shown.
    property var opened: null
    property string selected
    property string body
    property string problem
    signal navigated()
    signal sourcesRequested()
    readonly property string helper: "/usr/libexec/desktop/licenses"
    readonly property string query: search.text.toLowerCase()
    readonly property var shown: (opened ? opened.files : components).filter(c =>
        (c.name + (c.files ? " " + c.files.map(f => f.name).join(" ") : "")).toLowerCase().includes(query))

    spacing: 16
    onVisibleChanged: {
        if (visible) {
            selected = "";
            opened = null;
            search.text = "";
            problem = "";
            listing.running = true;
        }
    }

    function open(path: string) {
        if (reader.running)
            return;
        selected = path;
        body = "";
        problem = "";
        reader.command = [helper, "read", path];
        reader.running = true;
        navigated();
    }

    Process {
        id: listing
        command: [page.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    page.components = result.components ?? [];
                    page.problem = result.error ?? "";
                } catch (_) {
                    page.problem = "The license list could not be read.";
                }
            }
        }
    }
    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    page.body = result.text ?? "";
                    page.problem = result.error ?? "";
                } catch (_) {
                    page.problem = "This license file could not be read.";
                }
            }
        }
    }

    Text {
        width: parent.width
        wrapMode: Text.Wrap
        text: page.selected || page.opened?.name || "Licenses and notices for the system and its supported model downloads."
        color: Theme.textBody
        font { family: Theme.font; pixelSize: 13 }
    }
    Row {
        spacing: 12
        DialogButton {
            visible: page.selected !== "" || page.opened !== null
            text: page.selected ? "Component files" : "All components"
            onActivated: {
                if (page.selected)
                    page.selected = "";
                else
                    page.opened = null;
                search.text = "";
                page.problem = "";
                page.navigated();
            }
        }
        DialogButton {
            text: "Sources"
            onActivated: page.sourcesRequested()
        }
    }
    Rectangle {
        visible: !page.selected
        width: parent.width
        height: 36
        color: Theme.surface
        border.color: Theme.lineStrong

        TextInput {
            id: search
            anchors { fill: parent; margins: 10 }
            color: Theme.textStrong
            selectionColor: Theme.accent
            font { family: Theme.font; pixelSize: 13 }
            clip: true
        }
        Text {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            visible: search.text === ""
            text: page.opened ? "Find a notice" : "Find a component"
            color: Theme.textMuted
            font { family: Theme.font; pixelSize: 13 }
        }
    }
    Text {
        visible: page.problem !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: page.problem
        color: Theme.danger
        font { family: Theme.font; pixelSize: 13 }
    }
    ListView {
        id: list
        visible: !page.selected
        width: parent.width
        height: Math.min(480, contentHeight)
        clip: true
        model: page.shown
        onModelChanged: contentY = 0

        delegate: Rectangle {
            id: entry
            required property var modelData
            width: list.width
            height: 44
            color: hover.hovered ? Theme.hover : Theme.surface
            border.color: Theme.line

            Text {
                anchors { left: parent.left; right: count.left; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: entry.modelData.name
                elide: Text.ElideMiddle
                color: Theme.textStrong
                font { family: Theme.font; pixelSize: 13 }
            }
            Text {
                id: count
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: page.opened ? "Read" : `${entry.modelData.files.length} files`
                color: Theme.textMuted
                font { family: Theme.font; pixelSize: 12 }
            }
            TapHandler {
                onTapped: {
                    if (page.opened) {
                        page.open(entry.modelData.path);
                    } else {
                        page.opened = entry.modelData;
                        search.text = "";
                        page.navigated();
                    }
                }
            }
            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
    TextEdit {
        visible: page.selected !== ""
        width: parent.width
        text: page.body
        textFormat: TextEdit.PlainText
        readOnly: true
        selectByMouse: true
        wrapMode: TextEdit.Wrap
        color: Theme.textBody
        selectionColor: Theme.accent
        font { family: Theme.font; pixelSize: 13 }
    }
}
