// A line icon drawn from SVG path data on a grid, 16 by 16 unless set, like
// the demo's icons: `strokes` are outlined, `fills` are solid.
import QtQuick
import QtQuick.Shapes

Item {
    id: icon

    property string strokes
    property string fills
    property color color: Theme.text
    property int capStyle: ShapePath.FlatCap
    property real strokeWidth: 1.4
    // Dashed strokes, as for a capture's area.
    property bool dashed
    // The grid; wider icons (the input language) are 20 wide.
    property real gridWidth: 16
    property real gridHeight: 16

    implicitWidth: implicitHeight * gridWidth / gridHeight
    implicitHeight: 18

    Shape {
        width: icon.gridWidth
        height: icon.gridHeight
        scale: icon.height / icon.gridHeight
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: icon.strokes ? icon.color : "transparent"
            strokeWidth: icon.strokeWidth
            capStyle: icon.capStyle
            joinStyle: ShapePath.RoundJoin
            strokeStyle: icon.dashed ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: [2.5 / icon.strokeWidth, 2 / icon.strokeWidth]
            fillColor: "transparent"
            PathSvg { path: icon.strokes }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: icon.fills ? icon.color : "transparent"
            PathSvg { path: icon.fills }
        }
    }
}
