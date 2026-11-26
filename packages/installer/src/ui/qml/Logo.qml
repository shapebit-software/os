// The ShapeBit logo from the website, in the version for dark backgrounds: the
// wordmark, or with the mascot beside it.
import QtQuick

Image {
    property real size: 20
    property bool mascot: false

    objectName: "logo"
    source: mascot ? "../images/horizontal.png" : "../images/wordmark.png"
    height: size
    width: implicitHeight > 0 ? implicitWidth * size / implicitHeight : 0
    // Twice the size, to stay sharp on a high-density screen.
    sourceSize.height: size * 2
    fillMode: Image.PreserveAspectFit
}
