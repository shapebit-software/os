// The markup on a screenshot (Capture.qml), over the picked area of the
// frozen screen: arrows, highlights, numbered circles, and text, drawn with
// the `tool` in the `ink`. A drag draws an arrow or a highlight; a click puts
// the next number, or starts a text, which Enter ends. `save` writes the
// area with its markup at the screen's full resolution.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

Item {
    id: markup

    // The frozen screen, its size on the screen, and the area shown.
    property string source
    property size screenSize
    // Pixels for each point of the screen.
    property real pixelRatio: 1
    property string tool: "Arrow"
    property color ink: "#f05653"
    // The marks, in order: { kind, ink, and the points, the corner and size,
    // or the place and text }.
    property list<var> marks
    // The mark being drawn.
    property var draft: null
    readonly property bool editing: editor.visible

    function undo() {
        if (editing)
            editor.visible = false;
        else
            marks = marks.slice(0, -1);
    }

    // Ends a text being written, keeping it unless empty.
    function commit() {
        if (!editing)
            return;
        if (editor.text.trim())
            marks = marks.concat([{ kind: "Text", ink: ink, x: editor.x, y: editor.y, text: editor.text }]);
        editor.visible = false;
    }

    function save(path: string, done: var) {
        commit();
        grabToImage(result => done(result.saveToFile(path)),
            Qt.size(Math.round(width * pixelRatio), Math.round(height * pixelRatio)));
    }

    function nextNumber(): int {
        return marks.filter(m => m.kind === "Number").length + 1;
    }

    // The SVG path of an arrow from one point to another: the shaft, ending
    // where the filled head begins.
    function arrowHead(m: var): string {
        const angle = Math.atan2(m.y2 - m.y1, m.x2 - m.x1), length = 16, spread = 0.5;
        const at = (a, d) => `${m.x2 - d * Math.cos(a)},${m.y2 - d * Math.sin(a)}`;
        return `M${m.x2},${m.y2}L${at(angle - spread, length)}L${at(angle + spread, length)}z`;
    }
    function arrowShaft(m: var): string {
        const angle = Math.atan2(m.y2 - m.y1, m.x2 - m.x1);
        return `M${m.x1},${m.y1}L${m.x2 - 12 * Math.cos(angle)},${m.y2 - 12 * Math.sin(angle)}`;
    }

    clip: true

    Image {
        x: -markup.x
        y: -markup.y
        width: markup.screenSize.width
        height: markup.screenSize.height
        source: markup.source ? "file://" + markup.source : ""
        cache: false
        smooth: true
        mipmap: true
    }

    Repeater {
        model: markup.marks.concat(markup.draft ? [markup.draft] : [])

        Item {
            id: mark

            required property var modelData

            anchors.fill: parent

            Shape {
                visible: mark.modelData.kind === "Arrow"
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: mark.modelData.ink
                    strokeWidth: 4
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: mark.modelData.kind === "Arrow" ? markup.arrowShaft(mark.modelData) : "" }
                }
                ShapePath {
                    strokeColor: mark.modelData.ink
                    strokeWidth: 2
                    joinStyle: ShapePath.RoundJoin
                    fillColor: mark.modelData.ink
                    PathSvg { path: mark.modelData.kind === "Arrow" ? markup.arrowHead(mark.modelData) : "" }
                }
            }

            Rectangle {
                visible: mark.modelData.kind === "Highlight"
                x: mark.modelData.x ?? 0
                y: mark.modelData.y ?? 0
                width: mark.modelData.width ?? 0
                height: mark.modelData.height ?? 0
                color: Qt.alpha(mark.modelData.ink, 0.35)
            }

            Rectangle {
                visible: mark.modelData.kind === "Number"
                x: (mark.modelData.x ?? 0) - 14
                y: (mark.modelData.y ?? 0) - 14
                width: 28
                height: 28
                radius: 14
                color: mark.modelData.ink
                border.color: "white"
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: mark.modelData.n ?? ""
                    color: Qt.color(mark.modelData.ink).hslLightness > 0.6 ? "#1d1a24" : "white"
                    font { family: Theme.font; pixelSize: 14; weight: Font.Bold }
                }
            }

            Text {
                visible: mark.modelData.kind === "Text"
                x: mark.modelData.x ?? 0
                y: mark.modelData.y ?? 0
                text: mark.modelData.text ?? ""
                color: mark.modelData.ink
                style: Text.Outline
                styleColor: Qt.color(mark.modelData.ink).hslLightness > 0.6 ? "#1d1a24" : "white"
                font: editor.font
            }
        }
    }

    TextInput {
        id: editor

        visible: false
        color: markup.ink
        selectionColor: Theme.accent
        font { family: Theme.font; pixelSize: 20; weight: Font.DemiBold }
        onAccepted: markup.commit()
        Keys.onEscapePressed: visible = false

        // Where the text will go, before it has any.
        Rectangle {
            visible: !editor.text
            width: 2
            height: editor.height
            color: markup.ink
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: markup.tool === "Text" ? Qt.IBeamCursor : Qt.CrossCursor
        // The toolbar can lie over the area; its clicks are its own.
        property point start

        onPressed: mouse => {
            if (markup.toolbarHit(mapToItem(null, mouse.x, mouse.y))) {
                mouse.accepted = false;
                return;
            }
            markup.commit();
            start = Qt.point(mouse.x, mouse.y);
            if (markup.tool === "Number") {
                markup.marks = markup.marks.concat([{ kind: "Number", ink: markup.ink, x: mouse.x, y: mouse.y, n: markup.nextNumber() }]);
            } else if (markup.tool === "Text") {
                editor.text = "";
                editor.x = mouse.x;
                editor.y = mouse.y - editor.height / 2;
                editor.visible = true;
                editor.forceActiveFocus();
            }
        }
        onPositionChanged: mouse => {
            if (markup.tool === "Arrow")
                markup.draft = { kind: "Arrow", ink: markup.ink, x1: start.x, y1: start.y, x2: mouse.x, y2: mouse.y };
            else if (markup.tool === "Highlight")
                markup.draft = { kind: "Highlight", ink: markup.ink, x: Math.min(start.x, mouse.x), y: Math.min(start.y, mouse.y),
                    width: Math.abs(mouse.x - start.x), height: Math.abs(mouse.y - start.y) };
        }
        onReleased: {
            const d = markup.draft;
            if (d && (d.kind === "Arrow" ? Math.hypot(d.x2 - d.x1, d.y2 - d.y1) > 8 : d.width > 3 && d.height > 3))
                markup.marks = markup.marks.concat([d]);
            markup.draft = null;
        }
    }

    // Whether a point on the overlay is on its toolbar; set by the overlay.
    property var toolbarHit: point => false
}
