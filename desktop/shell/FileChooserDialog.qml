// The picker of the file chooser (FileChooser.qml), over everything, with the
// screens dimmed behind it: the places on the left; the folder's path, its
// files and folders, and the buttons on the right. A click selects, a double
// click opens a folder or chooses a file; Ctrl+click selects several where the
// application allows. Saving asks for a name and asks before replacing a
// file. Enter chooses, Backspace goes up a folder, Escape cancels.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property ShellScreen modelData

    readonly property var request: FileChooser.request
    // The picker is on one screen; the others are only dimmed.
    readonly property bool picking: request !== null && FileChooser.screen === (modelData?.name ?? "")
    readonly property bool saving: request?.save ?? false
    readonly property bool folders: request?.folders ?? false

    property string folder
    property list<string> selected
    property int filterIndex
    // Saving over a file that exists asks first.
    property bool replacing

    readonly property list<string> patterns: request?.filters?.[filterIndex]?.patterns ?? []
    readonly property string acceptLabel: request?.accept
        || (replacing ? "Replace" : saving ? "Save" : folders ? "Choose" : "Open")

    visible: request !== null
    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "file-chooser"
    WlrLayershell.keyboardFocus: picking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    onPickingChanged: {
        if (!picking)
            return;
        filterIndex = request.filter ?? 0;
        browse(request.folder || FileChooser.lastFolder);
        name.text = request.name ?? "";
        if (saving) {
            name.forceActiveFocus();
            name.select(0, name.text.lastIndexOf(".") > 0 ? name.text.lastIndexOf(".") : name.text.length);
        } else {
            list.forceActiveFocus();
        }
    }

    function browse(path: string) {
        folder = path;
        selected = [];
        replacing = false;
        list.currentIndex = -1;
    }

    function up() {
        if (folder !== "/")
            browse(folder.substring(0, folder.lastIndexOf("/")) || "/");
    }

    function pick(path: string, isDir: bool, adding: bool) {
        replacing = false;
        if (saving && !isDir)
            name.text = path.split("/").pop();
        if (adding && request.multiple)
            selected = selected.includes(path) ? selected.filter(p => p !== path) : selected.concat([path]);
        else
            selected = [path];
    }

    function isFolder(path: string): bool {
        const i = entries.indexOf("file://" + path);
        return i >= 0 && entries.get(i, "fileIsDir");
    }

    // Chooses what is selected, or opens it if it is one folder.
    function accept() {
        if (saving) {
            const file = name.text.trim();
            if (!file)
                return;
            const path = (folder === "/" ? "" : folder) + "/" + file;
            if (isFolder(path))
                browse(path);
            else if (entries.indexOf("file://" + path) >= 0 && !replacing)
                replacing = true;
            else
                FileChooser.choose([path], filterIndex);
        } else if (folders) {
            FileChooser.choose(selected.length ? selected : [folder], filterIndex);
        } else if (selected.length === 1 && isFolder(selected[0])) {
            browse(selected[0]);
        } else {
            const files = selected.filter(p => !isFolder(p));
            if (files.length)
                FileChooser.choose(files, filterIndex);
        }
    }

    function sizeText(bytes: real): string {
        return bytes < 1e3 ? `${bytes} B` : bytes < 1e6 ? `${Math.round(bytes / 1e3)} KB`
            : bytes < 1e9 ? `${(bytes / 1e6).toFixed(1)} MB` : `${(bytes / 1e9).toFixed(1)} GB`;
    }

    // Everything in the folder, to know what exists; the list shows only
    // what the filter lets through.
    FolderListModel {
        id: entries

        folder: "file://" + window.folder
        showHidden: true
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.05, 0.04, 0.09, 0.45)
    }

    PopoverFrame {
        visible: window.picking
        anchors.centerIn: parent
        padding: 0

        Item {
            id: body

            width: Math.min(820, window.width - 80)
            height: Math.min(540, window.height - 80)

            Keys.onEscapePressed: FileChooser.cancel()

            // The places.
            Rectangle {
                id: places

                width: 188
                height: parent.height
                color: Theme.veil(0.04)

                Column {
                    anchors { fill: parent; margins: 10 }
                    spacing: 2

                    Text {
                        width: parent.width
                        leftPadding: 8
                        topPadding: 6
                        bottomPadding: 14
                        elide: Text.ElideRight
                        text: window.request?.title || (window.saving ? "Save File" : "Open File")
                        color: Theme.ink
                        font { family: Theme.font; pixelSize: 15; weight: Font.DemiBold }
                    }

                    Repeater {
                        model: FileChooser.places

                        Rectangle {
                            id: place

                            required property var modelData
                            readonly property bool current: window.folder === modelData.path

                            width: parent.width
                            height: 32
                            color: current ? Theme.accentSoft : Theme.veil(placeHover.hovered ? 0.06 : 0)

                            Icon {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                height: 14
                                capStyle: ShapePath.RoundCap
                                color: place.current ? Theme.accent : Theme.inkSoft
                                strokes: place.modelData.path === FileChooser.home
                                    ? "M2.2 7.4L8 2.4l5.8 5M3.8 6.2v7.4h8.4V6.2"
                                    : "M1.8 4.2v8.3a.7.7 0 0 0 .7.7h11a.7.7 0 0 0 .7-.7V5.9a.7.7 0 0 0-.7-.7H8L6.6 3.5H2.5a.7.7 0 0 0-.7.7z"
                            }
                            Text {
                                x: 34
                                width: parent.width - 42
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: place.modelData.name
                                color: Theme.ink
                                font { family: Theme.font; pixelSize: 13; weight: place.current ? Font.Medium : Font.Normal }
                            }

                            TapHandler {
                                onTapped: window.browse(place.modelData.path)
                            }
                            HoverHandler {
                                id: placeHover
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }

            // The folder's path, each part a way back to it.
            Flickable {
                id: crumbs

                anchors { left: places.right; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18 }
                height: 52
                contentWidth: path.width
                contentX: Math.max(0, contentWidth - width)
                clip: true
                interactive: contentWidth > width

                Row {
                    id: path

                    height: parent.height

                    Repeater {
                        model: {
                            const inHome = (window.folder + "/").startsWith(FileChooser.home + "/");
                            const start = inHome ? FileChooser.home : "";
                            const parts = window.folder.substring(start.length).split("/").filter(p => p);
                            const all = [{ name: inHome ? "Home" : "Computer", path: start || "/" }];
                            for (const part of parts)
                                all.push({ name: part, path: all[all.length - 1].path.replace(/\/$/, "") + "/" + part });
                            return all;
                        }

                        Text {
                            id: crumb

                            required property var modelData
                            required property int index
                            readonly property bool last: modelData.path === window.folder

                            anchors.verticalCenter: parent.verticalCenter
                            text: (index ? "  ›  " : "") + modelData.name
                            color: last ? Theme.ink : crumbHover.hovered ? Theme.accent : Theme.inkFaint
                            font { family: Theme.font; pixelSize: 13; weight: last ? Font.Medium : Font.Normal }

                            TapHandler {
                                onTapped: window.browse(crumb.modelData.path)
                            }
                            HoverHandler {
                                id: crumbHover
                                cursorShape: crumb.last ? Qt.ArrowCursor : Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors { left: places.right; right: parent.right; top: crumbs.bottom }
                height: 1
                color: Theme.veil(0.08)
            }

            // The folder's files and folders.
            ListView {
                id: list

                anchors { left: places.right; right: parent.right; top: crumbs.bottom; bottom: footer.top; margins: 8 }
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: -1
                highlightMoveDuration: 0

                Keys.onReturnPressed: window.accept()
                Keys.onEnterPressed: window.accept()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Backspace)
                        window.up();
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        window.pick(shown.get(currentIndex, "filePath"), shown.get(currentIndex, "fileIsDir"), false);
                }

                model: FolderListModel {
                    id: shown

                    folder: "file://" + window.folder
                    nameFilters: window.patterns
                    caseSensitive: false
                    showDirsFirst: true
                    showDotAndDotDot: false
                    showFiles: !window.folders
                    sortCaseSensitive: false
                }

                delegate: Rectangle {
                    id: row

                    required property int index
                    required property string fileName
                    required property string filePath
                    required property bool fileIsDir
                    required property real fileSize
                    required property date fileModified
                    readonly property bool chosen: window.selected.includes(filePath)

                    width: ListView.view.width
                    height: 32
                    color: chosen ? Theme.accentSoft : Theme.veil(rowHover.hovered ? 0.05 : 0)

                    Icon {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: 14
                        capStyle: ShapePath.RoundCap
                        color: row.fileIsDir ? Theme.accent : Theme.inkFaint
                        strokes: row.fileIsDir
                            ? "M1.8 4.2v8.3a.7.7 0 0 0 .7.7h11a.7.7 0 0 0 .7-.7V5.9a.7.7 0 0 0-.7-.7H8L6.6 3.5H2.5a.7.7 0 0 0-.7.7z"
                            : "M3.5 1.8h6l3 3v9.4h-9zM9.5 1.8v3h3"
                    }
                    Text {
                        x: 34
                        width: parent.width - 34 - details.width - 20
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideMiddle
                        text: row.fileName
                        color: Theme.ink
                        font { family: Theme.font; pixelSize: 13 }
                    }
                    Text {
                        id: details

                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: (row.fileIsDir ? "" : window.sizeText(row.fileSize) + "   ")
                            + row.fileModified.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
                        color: Theme.inkFaint
                        font { family: Theme.mono; pixelSize: 11 }
                    }

                    TapHandler {
                        acceptedModifiers: Qt.NoModifier
                        onTapped: {
                            if (tapCount === 2) {
                                if (row.fileIsDir)
                                    window.browse(row.filePath);
                                else {
                                    window.pick(row.filePath, false, false);
                                    window.accept();
                                }
                                return;
                            }
                            window.pick(row.filePath, row.fileIsDir, false);
                            if (!window.saving)
                                list.forceActiveFocus();
                        }
                    }
                    TapHandler {
                        acceptedModifiers: Qt.ControlModifier
                        onTapped: window.pick(row.filePath, row.fileIsDir, true)
                    }
                    HoverHandler {
                        id: rowHover
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: window.folders ? "No folders here" : "Nothing here"
                    color: Theme.inkFaint
                    font { family: Theme.font; pixelSize: 13 }
                }
            }

            // The name to save as, the filters, and the buttons.
            Item {
                id: footer

                anchors { left: places.right; right: parent.right; bottom: parent.bottom }
                height: 60

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.veil(0.08)
                }

                Rectangle {
                    id: field

                    visible: window.saving
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(280, buttons.x - x - filters.width - 24)
                    height: 34
                    color: Theme.veil(0.06)
                    border.color: window.replacing ? Theme.danger : "transparent"

                    TextInput {
                        id: name

                        anchors { left: parent.left; right: parent.right; leftMargin: 11; rightMargin: 11 }
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.ink
                        selectionColor: Theme.accent
                        font { family: Theme.font; pixelSize: 13 }
                        clip: true
                        onTextEdited: window.replacing = false
                        onAccepted: window.accept()
                        Keys.onEscapePressed: FileChooser.cancel()

                        Text {
                            visible: !name.text
                            text: "Name"
                            color: Theme.inkFaint
                            font: name.font
                        }
                    }
                }

                // Asking before replacing, otherwise how many are selected.
                Text {
                    x: window.saving ? field.x + field.width + 12 : 18
                    width: buttons.x - x - filters.width - 24
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: window.replacing ? "Already exists"
                        : window.selected.length > 1 ? `${window.selected.length} selected` : ""
                    color: window.replacing ? Theme.danger : Theme.inkFaint
                    font { family: Theme.font; pixelSize: 12 }
                }

                Row {
                    id: filters

                    anchors { right: buttons.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    visible: (window.request?.filters?.length ?? 0) > 1
                    spacing: 2

                    Repeater {
                        model: filters.visible ? window.request.filters : []

                        Rectangle {
                            id: chip

                            required property var modelData
                            required property int index
                            readonly property bool current: index === window.filterIndex

                            width: chipLabel.width + 20
                            height: 28
                            color: current ? Theme.accentSoft : Theme.veil(chipHover.hovered ? 0.07 : 0.03)

                            Text {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: chip.modelData.name
                                color: chip.current ? Theme.accent : Theme.inkSoft
                                font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
                            }
                            TapHandler {
                                onTapped: window.filterIndex = chip.index
                            }
                            HoverHandler {
                                id: chipHover
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }

                Row {
                    id: buttons

                    anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    spacing: 4

                    DialogButton {
                        text: "Cancel"
                        onActivated: FileChooser.cancel()
                    }
                    DialogButton {
                        text: window.acceptLabel
                        strong: true
                        opacity: enabled ? 1 : 0.45
                        enabled: window.saving ? name.text.trim() !== "" : window.folders || window.selected.length > 0
                        onActivated: window.accept()
                    }
                }
            }
        }
    }
}
