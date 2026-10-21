// A line icon drawn from SVG path data on a 16 by 16 grid, like the demo's
// icons: `strokes` are outlined, `fills` are solid.
import QtQuick
import QtQuick.Shapes

Item {
    id: icon

    property string strokes
    property string fills
    property color color: Theme.text
    property int capStyle: ShapePath.FlatCap
    // The width of the grid; wider icons (the input language) use 20.
    property real gridWidth: 16

    implicitWidth: 18 * gridWidth / 16
    implicitHeight: 18

    Shape {
        width: icon.gridWidth
        height: 16
        scale: icon.height / 16
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: icon.strokes ? icon.color : "transparent"
            strokeWidth: 1.4
            capStyle: icon.capStyle
            joinStyle: ShapePath.RoundJoin
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
