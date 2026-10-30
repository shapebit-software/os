// The markup on a screenshot (Capture.qml), over the picked area of the
// frozen screen: arrows, highlights, pixelated areas, numbered circles, and
// text, drawn with the `tool` in the `ink`. A drag draws an arrow, a
// highlight, or a pixelated area; a click puts the next number, or starts a
// text, which Enter ends, or edits the text clicked. With Move, a click
// picks the mark under the pointer, which a drag moves and `remove` deletes.
// Undo and Redo step through every change.
// `save` writes the area with its markup at the screen's full resolution.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.services

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
    // or the place, text, and size }; the marks before each change, and
    // after each one undone.
    property list<var> marks
    property list<var> history
    property list<var> future
    // The mark picked with Move, or -1.
    property int selected: -1
    // The mark being drawn.
    property var draft: null
    readonly property bool editing: editor.visible

    onToolChanged: selected = -1

    function clear() {
        selected = -1;
        marks = [];
        history = [];
        future = [];
    }

    // The marks changed, with the ones before kept for Undo.
    function change(next: list<var>, before: list<var>) {
        history = history.concat([before]);
        future = [];
        marks = next;
    }

    function remove() {
        if (selected < 0)
            return;
        change(marks.filter((m, i) => i !== selected), marks);
        selected = -1;
    }

    function undo() {
        selected = -1;
        if (editing) {
            editor.visible = false;
        } else if (history.length) {
            future = future.concat([marks]);
            marks = history[history.length - 1];
            history = history.slice(0, -1);
        }
    }

    function redo() {
        if (editing || !future.length)
            return;
        selected = -1;
        history = history.concat([marks]);
        marks = future[future.length - 1];
        future = future.slice(0, -1);
    }

    // Starts a text at a point, or edits the text there.
    function write(x: real, y: real) {
        const i = markAt(x, y);
        editor.index = i >= 0 && marks[i].kind === "Text" ? i : -1;
        if (editor.index >= 0) {
            const m = marks[i];
            ink = m.ink;
            editor.text = m.text;
            editor.x = m.x;
            editor.y = m.y;
        } else {
            editor.text = "";
            editor.x = x;
            editor.y = y - editor.height / 2;
        }
        editor.visible = true;
        editor.cursorPosition = editor.text.length;
        editor.forceActiveFocus();
    }

    // Ends a text being written, keeping it unless empty; an edited one
    // stays where it was among the marks.
    function commit() {
        if (!editing)
            return;
        editor.visible = false;
        const text = { kind: "Text", ink: ink, x: editor.x, y: editor.y, text: editor.text,
            width: editor.width, height: editor.height };
        const i = editor.index, kept = editor.text.trim() !== "";
        if (i < 0) {
            if (kept)
                change(marks.concat([text]), marks);
        } else if (!kept) {
            change(marks.filter((m, j) => j !== i), marks);
        } else if (text.text !== marks[i].text || !Qt.colorEqual(text.ink, marks[i].ink)) {
            change(marks.map((m, j) => j === i ? text : m), marks);
        }
    }

    function save(path: string, done: var) {
        commit();
        // The outline is not part of the picture.
        selected = -1;
        grabToImage(result => done(result.saveToFile(path)),
            Qt.size(Math.round(width * pixelRatio), Math.round(height * pixelRatio)));
    }

    function nextNumber(): int {
        return marks.filter(m => m.kind === "Number").length + 1;
    }

    // The topmost mark at a point, or -1.
    function markAt(x: real, y: real): int {
        for (let i = marks.length - 1; i >= 0; i--) {
            const m = marks[i];
            if (m.kind === "Arrow") {
                const dx = m.x2 - m.x1, dy = m.y2 - m.y1;
                const t = Math.max(0, Math.min(1, ((x - m.x1) * dx + (y - m.y1) * dy) / (dx * dx + dy * dy)));
                if (Math.hypot(x - m.x1 - t * dx, y - m.y1 - t * dy) < 10)
                    return i;
            } else if (m.kind === "Number") {
                if (Math.hypot(x - m.x, y - m.y) < 16)
                    return i;
            } else if (x >= m.x - 4 && x < m.x + m.width + 4 && y >= m.y - 4 && y < m.y + m.height + 4) {
                return i;
            }
        }
        return -1;
    }

    // The box around a mark.
    function bounds(m: var): rect {
        if (m.kind === "Arrow")
            return Qt.rect(Math.min(m.x1, m.x2), Math.min(m.y1, m.y2), Math.abs(m.x2 - m.x1), Math.abs(m.y2 - m.y1));
        if (m.kind === "Number")
            return Qt.rect(m.x - 14, m.y - 14, 28, 28);
        return Qt.rect(m.x, m.y, m.width, m.height);
    }

    // A mark moved by an offset.
    function moved(m: var, dx: real, dy: real): var {
        const next = Object.assign({}, m);
        if (m.kind === "Arrow") {
            next.x1 += dx;
            next.y1 += dy;
            next.x2 += dx;
            next.y2 += dy;
        } else {
            next.x += dx;
            next.y += dy;
        }
        return next;
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
        id: frozen

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
            required property int index

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

            // Pixelated: the frozen screen there, shrunk and shown unsmoothed.
            ShaderEffectSource {
                visible: mark.modelData.kind === "Pixelate"
                x: mark.modelData.x ?? 0
                y: mark.modelData.y ?? 0
                width: mark.modelData.width ?? 0
                height: mark.modelData.height ?? 0
                sourceItem: visible ? frozen : null
                sourceRect: Qt.rect(x + markup.x, y + markup.y, width, height)
                textureSize: Qt.size(Math.max(1, Math.round(width / 10)), Math.max(1, Math.round(height / 10)))
                smooth: false
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
                // Hidden while it is being edited.
                visible: mark.modelData.kind === "Text" && !(markup.editing && editor.index === mark.index)
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

    // The mark picked, outlined.
    Rectangle {
        readonly property rect box: markup.selected >= 0 && markup.selected < markup.marks.length
            ? markup.bounds(markup.marks[markup.selected]) : Qt.rect(0, 0, 0, 0)

        visible: markup.selected >= 0
        x: box.x - 6
        y: box.y - 6
        width: box.width + 12
        height: box.height + 12
        radius: 4
        color: "transparent"
        border.color: Theme.accent
        border.width: 2
    }

    TextInput {
        id: editor

        // The text being edited among the marks, or -1 for a new one.
        property int index: -1

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
        hoverEnabled: markup.tool === "Move"
        cursorShape: markup.tool === "Text" ? Qt.IBeamCursor
            : markup.tool !== "Move" ? Qt.CrossCursor
            : moving >= 0 ? Qt.ClosedHandCursor
            : markup.markAt(mouseX, mouseY) >= 0 ? Qt.OpenHandCursor : Qt.ArrowCursor
        // The toolbar can lie over the area; its clicks are its own.
        property point start
        // The mark being moved, or -1, and the marks before.
        property int moving: -1
        property list<var> before

        onPressed: mouse => {
            if (markup.toolbarHit(mapToItem(null, mouse.x, mouse.y))) {
                mouse.accepted = false;
                return;
            }
            markup.commit();
            start = Qt.point(mouse.x, mouse.y);
            if (markup.tool === "Move") {
                moving = markup.markAt(mouse.x, mouse.y);
                markup.selected = moving;
                before = markup.marks;
            } else if (markup.tool === "Number") {
                markup.change(markup.marks.concat([{ kind: "Number", ink: markup.ink, x: mouse.x, y: mouse.y, n: markup.nextNumber() }]), markup.marks);
            } else if (markup.tool === "Text") {
                markup.write(mouse.x, mouse.y);
            }
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            if (moving >= 0)
                markup.marks = before.map((m, i) => i === moving ? markup.moved(m, mouse.x - start.x, mouse.y - start.y) : m);
            else if (markup.tool === "Arrow")
                markup.draft = { kind: "Arrow", ink: markup.ink, x1: start.x, y1: start.y, x2: mouse.x, y2: mouse.y };
            else if (markup.tool === "Highlight" || markup.tool === "Pixelate")
                markup.draft = { kind: markup.tool, ink: markup.ink, x: Math.min(start.x, mouse.x), y: Math.min(start.y, mouse.y),
                    width: Math.abs(mouse.x - start.x), height: Math.abs(mouse.y - start.y) };
        }
        onReleased: mouse => {
            if (moving >= 0 && (mouse.x !== start.x || mouse.y !== start.y))
                markup.change(markup.marks, before);
            moving = -1;
            const d = markup.draft;
            if (d && (d.kind === "Arrow" ? Math.hypot(d.x2 - d.x1, d.y2 - d.y1) > 8 : d.width > 3 && d.height > 3))
                markup.change(markup.marks.concat([d]), markup.marks);
            markup.draft = null;
        }
    }

    // Whether a point on the overlay is on its toolbar; set by the overlay.
    property var toolbarHit: point => false
}
