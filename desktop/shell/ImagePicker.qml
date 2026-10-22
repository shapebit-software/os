// A page of Settings for choosing a picture: the images in Pictures and its
// folders, newest first. A click on one picks it.
pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell

Column {
    id: picker

    // The folder shown, inside Pictures.
    property url folder: "file://" + home + "/Pictures"
    readonly property string home: Quickshell.env("HOME")
    signal picked(string path)

    spacing: 12

    // The way back up, when inside a folder of Pictures.
    Text {
        visible: images.folder.toString() !== "file://" + picker.home + "/Pictures"
        text: "‹ " + images.parentFolder.toString().split("/").pop()
        color: Theme.accent
        font { family: Theme.font; pixelSize: 12; weight: Font.Medium }

        TapHandler {
            onTapped: images.folder = images.parentFolder
        }
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }

    Grid {
        id: grid

        readonly property real tileWidth: (width - 3 * spacing) / 4

        width: parent.width
        columns: 4
        spacing: 10

        Repeater {
            model: FolderListModel {
                id: images

                folder: picker.folder
                nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg"]
                showDirsFirst: true
                showDotAndDotDot: false
                sortField: FolderListModel.Time
            }

            Item {
                id: tile

                required property string filePath
                required property string fileName
                required property bool fileIsDir

                width: grid.tileWidth
                height: Math.round(width * 0.62)
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: tileHover.hovered ? "#e1e4e7" : "#eceff1"
                    border.color: "#d8dbde"
                }
                Image {
                    anchors.fill: parent
                    visible: !tile.fileIsDir
                    source: tile.fileIsDir ? "" : "file://" + tile.filePath
                    sourceSize.width: 320
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                // A folder: its name.
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    visible: tile.fileIsDir
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    text: tile.fileName + " ›"
                    color: "#44484d"
                    font { family: Theme.font; pixelSize: 12 }
                }

                TapHandler {
                    onTapped: tile.fileIsDir ? images.folder = "file://" + tile.filePath : picker.picked(tile.filePath)
                }
                HoverHandler {
                    id: tileHover
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    Text {
        visible: images.status === FolderListModel.Ready && images.count === 0
        text: "No pictures in this folder"
        color: "#5f6469"
        font { family: Theme.font; pixelSize: 13 }
    }
}
