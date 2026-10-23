// The capture overlay (Capture.qml) over one screen, dimmed, with a panel at
// the bottom in the popovers' light glass, in two rows: what to pick (a
// selection, a window, or the screen), as one segmented control; and the
// timer, a switch between a screenshot and a recording whose knob is the
// capture button, and the option of the kind chosen: Edit, which opens
// screenshots for markup before they are saved (Settings.captureMarkup), or
// Mic, which records the microphone (Settings.captureMicrophone). Cancel sits on the panel's corner;
// until something is picked, the middle of the screen says what to do. A
// drag draws the selection, which shows its size in pixels, moves when
// dragged from inside, resizes from its corners, and is kept for next time;
// in Window, a click picks the window under the pointer. The capture button
// or Enter captures; Escape cancels.
//
// With Edit, the screenshot shows for markup (CaptureMarkup.qml), with its
// tools and colors, Undo, Copy, and Save; Enter saves. Without, the screen
// flashes where it was taken. During the timer, only the countdown shows,
// and lets clicks through.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: overlay

    required property ShellScreen modelData

    readonly property bool here: Capture.screen === modelData
    readonly property bool portal: Capture.request !== null
    // Under the compositor's blur threshold for this namespace, so what is
    // dimmed stays sharp (compositor/hyprland.lua).
    readonly property color dim: Qt.rgba(0.05, 0.04, 0.09, 0.45)
    readonly property color red: "#e5484d"
    // A screenshot's symbol, a camera, and a recording's, a video camera.
    readonly property string camera: "M2.75 7.25a1.5 1.5 0 0 1 1.5-1.5h2l1.25-2h5l1.25 2h2a1.5 1.5 0 0 1 1.5 1.5v7.5a1.5 1.5 0 0 1-1.5 1.5H4.25a1.5 1.5 0 0 1-1.5-1.5zM7 10.5a3 3 0 1 0 6 0a3 3 0 1 0-6 0z"
    readonly property string video: "M2.75 6.75a1.5 1.5 0 0 1 1.5-1.5h7a1.5 1.5 0 0 1 1.5 1.5v6.5a1.5 1.5 0 0 1-1.5 1.5h-7a1.5 1.5 0 0 1-1.5-1.5zM12.75 8.75l4.5-2.5v7.5l-4.5-2.5"
    // The capture panel's fill, and the tracks of its controls.
    readonly property color panelFill: Theme.oklch(0.94, 0.006, 285)
    readonly property color track: Theme.oklch(0.885, 0.01, 285)

    PanelWindow {
        id: window

        readonly property bool marking: Capture.stage === "markup"
        // What is picked: the selection drawn, the window clicked, or the
        // screen; and what lights up: that, or the window under the pointer.
        property rect picked
        property rect hovered
        readonly property rect lit: marking ? Capture.area
            : Capture.mode === "Screen" ? whole
            : Capture.mode === "Window" && picked.width === 0 ? hovered : picked
        readonly property bool ready: picked.width >= 4 && picked.height >= 4 || Capture.mode === "Screen"
        // The windows on the screen's workspace, in its coordinates.
        readonly property list<var> windows: Hyprland.toplevels.values
            .filter(t => t.workspace?.active && t.monitor?.name === overlay.modelData.name && t.lastIpcObject.at)
            .map(t => {
                const ipc = t.lastIpcObject;
                return Qt.rect(ipc.at[0] - overlay.modelData.x, ipc.at[1] - overlay.modelData.y, ipc.size[0], ipc.size[1]);
            })
        readonly property rect whole: Qt.rect(0, 0, width, height)
        readonly property real pixels: overlay.modelData?.devicePixelRatio ?? 1

        visible: overlay.here && (Capture.stage === "select" || marking)
        screen: overlay.modelData
        color: "transparent"
        // The compositor shows and hides this namespace at once, so the
        // overlay is out of the capture (compositor/hyprland.lua).
        WlrLayershell.namespace: "capture"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        onVisibleChanged: {
            if (visible && !marking) {
                pickWhat(Capture.mode);
                keys.forceActiveFocus();
            }
        }
        onMarkingChanged: {
            if (marking) {
                markup.marks = [];
                keys.forceActiveFocus();
            }
        }

        function pickWhat(mode: string) {
            Capture.mode = mode;
            picked = mode === "Area" ? Capture.lastArea : Qt.rect(0, 0, 0, 0);
            hovered = Qt.rect(0, 0, 0, 0);
        }

        function capture() {
            if (ready)
                Capture.take(Capture.mode === "Screen" ? whole : picked);
        }

        // Whether a point is on the bar or Cancel, whose clicks are their own.
        function onBar(point: point): bool {
            const items = marking ? [markupBar] : [selectPanel, closer];
            return items.some(i => i.visible && i.contains(i.mapFromItem(null, point.x, point.y)));
        }

        function windowAt(x: real, y: real): rect {
            return windows.find(r => x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height) ?? Qt.rect(0, 0, 0, 0);
        }

        // The selection kept inside the screen.
        function bounded(r: rect): rect {
            const x = Math.max(0, Math.min(r.x, width - r.width)), y = Math.max(0, Math.min(r.y, height - r.height));
            return Qt.rect(x, y, Math.min(r.width, width), Math.min(r.height, height));
        }

        function save() {
            const path = Capture.screenshotPath();
            markup.save(path, ok => ok ? Capture.saved(path) : Capture.cancel());
        }

        function copy() {
            const path = `${Capture.runtime}/capture-copy.png`;
            markup.save(path, ok => ok ? Capture.copied(path) : Capture.cancel());
        }

        Item {
            id: keys

            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: Capture.cancel()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (window.marking)
                        window.save();
                    else
                        window.capture();
                } else if (window.marking && event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_Z)
                        markup.undo();
                    else if (event.key === Qt.Key_C)
                        window.copy();
                }
            }
        }

        // The dimmed screen around what is lit; the frozen screen during
        // markup, the live one while picking.
        Image {
            anchors.fill: parent
            visible: window.marking
            source: window.marking ? "file://" + Capture.frozen : ""
            cache: false
            smooth: true
        }
        Repeater {
            model: [
                Qt.rect(0, 0, window.width, window.lit.y),
                Qt.rect(0, window.lit.y + window.lit.height, window.width, window.height - window.lit.y - window.lit.height),
                Qt.rect(0, window.lit.y, window.lit.x, window.lit.height),
                Qt.rect(window.lit.x + window.lit.width, window.lit.y, window.width - window.lit.x - window.lit.width, window.lit.height),
            ]

            Rectangle {
                required property rect modelData

                x: modelData.x
                y: modelData.y
                width: Math.max(0, modelData.width)
                height: Math.max(0, modelData.height)
                color: overlay.dim
            }
        }

        // Picking: drawing or moving the selection, or a window.
        MouseArea {
            id: picker

            property point start
            property rect from
            // "draw", "move", or none.
            property string dragging
            readonly property bool overPicked: window.picked.width > 0
                && window.picked.x <= mouseX && mouseX < window.picked.x + window.picked.width
                && window.picked.y <= mouseY && mouseY < window.picked.y + window.picked.height

            anchors.fill: parent
            visible: !window.marking
            hoverEnabled: true
            cursorShape: Capture.mode === "Window" ? Qt.PointingHandCursor
                : Capture.mode === "Screen" ? Qt.ArrowCursor
                : dragging === "move" || overPicked && dragging === "" ? Qt.SizeAllCursor
                : Qt.CrossCursor

            onPressed: mouse => {
                if (window.onBar(Qt.point(mouse.x, mouse.y))) {
                    mouse.accepted = false;
                    return;
                }
                if (Capture.mode === "Screen") {
                    mouse.accepted = false;
                    return;
                }
                if (Capture.mode === "Window") {
                    window.picked = window.windowAt(mouse.x, mouse.y);
                    return;
                }
                start = Qt.point(mouse.x, mouse.y);
                from = window.picked;
                dragging = overPicked ? "move" : "draw";
                if (dragging === "draw")
                    window.picked = Qt.rect(mouse.x, mouse.y, 0, 0);
            }
            onPositionChanged: mouse => {
                if (dragging === "draw")
                    window.picked = Qt.rect(Math.min(start.x, mouse.x), Math.min(start.y, mouse.y),
                        Math.abs(mouse.x - start.x), Math.abs(mouse.y - start.y));
                else if (dragging === "move")
                    window.picked = window.bounded(Qt.rect(from.x + mouse.x - start.x, from.y + mouse.y - start.y, from.width, from.height));
                else if (Capture.mode === "Window")
                    window.hovered = window.windowAt(mouse.x, mouse.y);
            }
            onReleased: {
                if (dragging === "draw" && (window.picked.width < 4 || window.picked.height < 4))
                    window.picked = from;
                dragging = "";
                if (Capture.mode === "Area")
                    Capture.lastArea = window.picked;
            }
        }

        // The edge of what is lit, the corners that resize a selection, and
        // its size in pixels.
        Rectangle {
            readonly property bool chosen: Capture.mode === "Window" && window.picked.width > 0

            x: window.lit.x - 1
            y: window.lit.y - 1
            width: window.lit.width + 2
            height: window.lit.height + 2
            visible: window.lit.width > 0 && !window.marking && Capture.mode !== "Screen"
            color: "transparent"
            border.color: chosen ? Theme.accent : "white"
            border.width: chosen ? 3 : 1.5
        }
        Repeater {
            model: Capture.mode === "Area" && window.picked.width > 0 && !window.marking ? [[0, 0], [1, 0], [0, 1], [1, 1]] : []

            Rectangle {
                id: handle

                required property var modelData
                property rect from
                property point start

                x: window.picked.x + modelData[0] * window.picked.width - width / 2
                y: window.picked.y + modelData[1] * window.picked.height - height / 2
                width: 12
                height: 12
                radius: 6
                color: "white"
                border.color: Qt.rgba(0, 0, 0, 0.25)

                // The opposite corner stays where it is.
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: handle.modelData[0] === handle.modelData[1] ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor

                    onPressed: mouse => {
                        handle.from = window.picked;
                        handle.start = mapToItem(null, mouse.x, mouse.y);
                    }
                    onPositionChanged: mouse => {
                        const at = mapToItem(null, mouse.x, mouse.y), f = handle.from;
                        const fixedX = handle.modelData[0] ? f.x : f.x + f.width;
                        const fixedY = handle.modelData[1] ? f.y : f.y + f.height;
                        const x = (handle.modelData[0] ? f.x + f.width : f.x) + at.x - handle.start.x;
                        const y = (handle.modelData[1] ? f.y + f.height : f.y) + at.y - handle.start.y;
                        window.picked = Qt.rect(Math.min(fixedX, x), Math.min(fixedY, y), Math.abs(x - fixedX), Math.abs(y - fixedY));
                    }
                    onReleased: Capture.lastArea = window.picked
                }
            }
        }
        Rectangle {
            readonly property bool below: window.lit.y + window.lit.height + height + 12 < selectPanel.y - 8

            visible: window.lit.width > 0 && !window.marking
            x: Math.min(window.width - width - 8, Math.max(8, window.lit.x + (window.lit.width - width) / 2))
            y: below ? window.lit.y + window.lit.height + 10 : Math.max(8, window.lit.y + 10)
            width: size.width + 16
            height: 22
            color: Qt.rgba(0.05, 0.04, 0.09, 0.7)

            Text {
                id: size
                anchors.centerIn: parent
                text: `${Math.round(window.lit.width * window.pixels)} × ${Math.round(window.lit.height * window.pixels)}`
                color: "white"
                font { family: Theme.mono; pixelSize: 11 }
            }
        }

        // The screenshot for markup, where it was on the screen.
        CaptureMarkup {
            id: markup

            visible: window.marking
            x: window.lit.x
            y: window.lit.y
            width: window.lit.width
            height: window.lit.height
            source: window.marking ? Capture.frozen : ""
            screenSize: Qt.size(window.width, window.height)
            pixelRatio: window.pixels
            toolbarHit: point => window.onBar(point)
        }

        // What to do first, in the middle of the screen, until it is done.
        Text {
            anchors.centerIn: parent
            visible: !window.marking && !window.ready && !picker.dragging
                && !(Capture.mode === "Window" && window.hovered.width > 0)
            text: Capture.mode === "Window" ? "Click a window" : "Drag to select an area"
            color: "white"
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.4)
            font { family: Theme.font; pixelSize: 15; weight: Font.Medium }
        }

        // The panel, in two rows: what to pick, as one segmented control;
        // and the timer, the switch between a screenshot and a recording
        // whose knob captures, and Edit. Cancel sits on its corner.
        // Rounded always, as the design has it, whatever the windows' corners.
        Item {
            id: selectPanel

            readonly property real inner: 388
            readonly property real padding: 12

            visible: !window.marking
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - (Settings.dock === "Bottom" ? Theme.gap : 28)
            width: inner + 2 * padding
            height: rows.height + 2 * padding

            RectangularShadow {
                anchors.fill: parent
                offset.y: 8
                blur: 24
                radius: 16
                color: Qt.rgba(0, 0, 0, 0.3)
            }
            Rectangle {
                anchors.fill: parent
                radius: 16
                color: overlay.panelFill
            }

            Column {
                id: rows

                x: selectPanel.padding
                y: selectPanel.padding
                width: selectPanel.inner
                spacing: 12

                // What to pick: the chosen one raised in white.
                Rectangle {
                    width: selectPanel.inner
                    height: 48
                    radius: 12
                    color: overlay.track

                    Row {
                        anchors.centerIn: parent
                        spacing: 2

                        Choice {
                            text: "Selection"
                            mode: "Area"
                            strokes: "M3.5 7V3.5H7M13 3.5h3.5V7M16.5 13v3.5H13M7 16.5H3.5V13"
                        }
                        Choice {
                            text: "Window"
                            mode: "Window"
                            strokes: "M2.75 4.25h14.5v11.5H2.75zM2.75 7.5h14.5"
                        }
                        Choice {
                            text: "Screen"
                            mode: "Screen"
                            strokes: "M2.75 3.75h14.5v9.5H2.75zM7 16.25h6M10 13.25v3"
                        }
                    }
                }

                Item {
                    width: selectPanel.inner
                    height: 60

                    // The timer: none, 3 seconds, or 10.
                    Option {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: Capture.delay ? `${Capture.delay} s` : "Off"
                        tip: "Timer"
                        on: Capture.delay > 0
                        strokes: "M4.5 11a5.5 5.5 0 1 0 11 0a5.5 5.5 0 1 0-11 0zM10 8v3l2 1.5M8 2.75h4"
                        onActivated: Capture.delay = Capture.delay === 0 ? 3 : Capture.delay === 3 ? 10 : 0
                    }

                    // The switch: a screenshot on the left, a recording on the
                    // right. A click on the free side moves the knob there;
                    // the knob, with its kind's symbol, captures.
                    Rectangle {
                        id: kinds

                        readonly property real knob: 112

                        anchors.centerIn: parent
                        width: 184
                        height: 62
                        radius: 18
                        color: overlay.track

                        // The other kind, on the free side.
                        Item {
                            id: other

                            x: Capture.record ? 0 : kinds.knob
                            width: kinds.width - kinds.knob
                            height: kinds.height
                            enabled: !overlay.portal || Capture.record
                            opacity: enabled ? 1 : 0.35

                            Icon {
                                anchors.centerIn: parent
                                height: 22
                                gridWidth: 20
                                gridHeight: 20
                                strokeWidth: 1.6
                                capStyle: ShapePath.RoundCap
                                color: otherHover.hovered && other.enabled ? Theme.ink : Theme.inkSoft
                                strokes: Capture.record ? overlay.camera : overlay.video
                            }
                            TapHandler {
                                enabled: other.enabled
                                onTapped: Capture.record = !Capture.record
                            }
                            HoverHandler {
                                id: otherHover
                                cursorShape: other.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                            Tooltip {
                                target: other
                                edge: "Bottom"
                                text: Capture.record ? "Screenshot" : "Recording"
                                hovered: otherHover.hovered && other.enabled
                            }
                        }

                        // The knob: the capture button, muted until there is
                        // something to capture.
                        Rectangle {
                            id: shutter

                            x: Capture.record ? kinds.width - width - 4 : 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: kinds.knob
                            height: kinds.height - 8
                            radius: 14
                            color: !window.ready ? Theme.oklch(0.68, 0.025, 285)
                                : Capture.record ? overlay.red : Theme.accent
                            scale: shutterTap.pressed ? 0.94 : 1

                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Behavior on scale { NumberAnimation { duration: 90 } }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "white"
                                opacity: shutterHover.hovered && window.ready ? 0.12 : 0
                            }
                            Icon {
                                anchors.centerIn: parent
                                height: 24
                                gridWidth: 20
                                gridHeight: 20
                                strokeWidth: 1.6
                                capStyle: ShapePath.RoundCap
                                color: "white"
                                strokes: Capture.record ? overlay.video : overlay.camera
                            }
                            TapHandler {
                                id: shutterTap
                                onTapped: window.capture()
                            }
                            HoverHandler {
                                id: shutterHover
                                cursorShape: window.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                            Tooltip {
                                target: shutter
                                edge: "Bottom"
                                text: Capture.record ? "Start recording" : "Take screenshot"
                                hovered: shutterHover.hovered && window.ready
                            }
                        }
                    }

                    // The options of the kind chosen, beside the switch:
                    // markup before saving for screenshots, and the
                    // microphone for recordings.
                    Option {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        visible: !Capture.record
                        text: "Edit"
                        tip: "Edit before saving"
                        on: Settings.captureMarkup && !Capture.record
                        strokes: "M4 16l1-4 8.5-8.5 3 3L8 15zM11.5 5.5l3 3"
                        onActivated: Settings.captureMarkup = !Settings.captureMarkup
                    }
                    Option {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        visible: Capture.record
                        text: "Mic"
                        tip: "Record the microphone"
                        on: Settings.captureMicrophone
                        strokes: "M7.5 5a2.5 2.5 0 0 1 5 0v5a2.5 2.5 0 0 1-5 0zM4.75 9.5a5.25 5.25 0 0 0 10.5 0M10 14.75v2.5"
                        onActivated: Settings.captureMicrophone = !Settings.captureMicrophone
                    }
                }
            }
        }

        // Cancel, on the panel's top right corner, half outside it.
        Rectangle {
            id: closer

            visible: !window.marking
            x: selectPanel.x + selectPanel.width - width / 2
            y: selectPanel.y - height / 2
            width: 28
            height: 28
            radius: 14
            color: closeHover.hovered ? Theme.popoverBottom : Theme.popoverTop
            border.color: Theme.popoverRing

            Icon {
                anchors.centerIn: parent
                height: 10
                strokeWidth: 1.8
                capStyle: ShapePath.RoundCap
                color: Theme.ink
                strokes: "M4 4l8 8M12 4l-8 8"
            }
            TapHandler {
                onTapped: Capture.cancel()
            }
            HoverHandler {
                id: closeHover
                cursorShape: Qt.PointingHandCursor
            }
            Tooltip {
                target: closer
                edge: "Bottom"
                text: "Cancel"
                hovered: closeHover.hovered
            }
        }

        // Markup: the tools and colors, Undo, and Cancel, Copy, and Save.
        Bar {
            id: markupBar

            visible: window.marking

            Repeater {
                model: [
                    { name: "Arrow", strokes: "M4 16L16 4M9.5 4H16v6.5" },
                    { name: "Highlight", strokes: "M3 17h14M5 13.5l7.5-7.5 2.5 2.5L7.5 16H5z" },
                    { name: "Number", strokes: "M3.5 10a6.5 6.5 0 1 0 13 0a6.5 6.5 0 1 0-13 0zM8.8 7.8l1.4-1v6.6" },
                    { name: "Text", strokes: "M4.5 5.5V4h11v1.5M10 4v12M8 16h4" },
                ]

                IconButton {
                    required property var modelData

                    tip: modelData.name
                    strokes: modelData.strokes
                    on: markup.tool === modelData.name
                    onActivated: markup.tool = modelData.name
                }
            }
            Divider {}
            Repeater {
                model: ["#f05653", "#f5c242", "#3f9cf0", "#ffffff"]

                Item {
                    id: swatch

                    required property color modelData
                    readonly property bool current: Qt.colorEqual(markup.ink, modelData)

                    anchors.verticalCenter: parent?.verticalCenter
                    width: 26
                    height: 36

                    Rectangle {
                        anchors.centerIn: parent
                        width: swatch.current ? 18 : swatchHover.hovered ? 16 : 14
                        height: width
                        radius: width / 2
                        color: swatch.modelData
                        border.color: swatch.current ? Theme.ink : Theme.veil(0.25)
                        border.width: swatch.current ? 2 : 1
                    }
                    TapHandler {
                        onTapped: markup.ink = swatch.modelData
                    }
                    HoverHandler {
                        id: swatchHover
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
            Divider {}
            IconButton {
                tip: "Undo"
                strokes: "M7 4.5 3.5 8l3.5 3.5M3.5 8H12a4 4 0 0 1 0 8H9"
                opacity: markup.marks.length || markup.editing ? 1 : 0.4
                onActivated: markup.undo()
            }
            Divider {}
            TextButton {
                text: "Cancel"
                onActivated: Capture.cancel()
            }
            TextButton {
                visible: !overlay.portal
                text: "Copy"
                onActivated: window.copy()
            }
            TextButton {
                text: overlay.portal ? "Share" : "Save"
                strong: true
                onActivated: window.save()
            }
        }
    }

    // The timer's countdown, which lets clicks through to the screen.
    PanelWindow {
        visible: overlay.here && Capture.stage === "wait" && Capture.countdown > 0
        screen: overlay.modelData
        color: "transparent"
        WlrLayershell.namespace: "capture"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors.bottom: true
        implicitWidth: 72
        // The countdown, and the space below it.
        implicitHeight: 112
        mask: Region {}

        Rectangle {
            width: 72
            height: 72
            radius: 36
            color: Qt.rgba(0.05, 0.04, 0.09, 0.7)

            Text {
                anchors.centerIn: parent
                text: Capture.countdown
                color: "white"
                font { family: Theme.font; pixelSize: 30; weight: Font.DemiBold }
            }
        }
    }

    // After a screenshot saved without markup: a flash where it was taken.
    PanelWindow {
        id: confirmation

        property rect area

        visible: flash.running
        screen: overlay.modelData
        color: "transparent"
        WlrLayershell.namespace: "capture"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        mask: Region {}

        Connections {
            target: Capture

            function onShot() {
                if (Capture.screen !== overlay.modelData)
                    return;
                confirmation.area = Capture.area;
                flash.restart();
            }
        }

        Rectangle {
            x: confirmation.area.x
            y: confirmation.area.y
            width: confirmation.area.width
            height: confirmation.area.height
            color: "white"
            opacity: 0

            NumberAnimation on opacity {
                id: flash
                running: false
                from: 0.8
                to: 0
                duration: 450
                easing.type: Easing.OutCubic
            }
        }
    }

    // The markup bar at the bottom center, in the popovers' light glass: in
    // the middle of the dock when the dock is at the bottom.
    component Bar: PopoverFrame {
        default property alias items: row.data

        anchors.horizontalCenter: parent.horizontalCenter
        y: Settings.dock === "Bottom" ? parent.height - Theme.gap - (Theme.stripHeight + height) / 2
            : parent.height - height - 28
        padding: 6

        Row {
            id: row
            spacing: 2
        }
    }

    // A button with an icon: lit while on. `tip` names it.
    component IconButton: Rectangle {
        id: button

        property string strokes
        property string tip
        property bool on
        signal activated

        anchors.verticalCenter: parent?.verticalCenter
        width: 36
        height: 36
        radius: Theme.rounded ? 6 : 0
        color: on ? Theme.accentSoft : Theme.veil(buttonHover.hovered ? 0.07 : 0)

        Icon {
            anchors.centerIn: parent
            height: 18
            gridWidth: 20
            gridHeight: 20
            strokeWidth: 1.5
            capStyle: ShapePath.RoundCap
            color: button.on ? Theme.accent : Theme.inkSoft
            strokes: button.strokes
        }

        TapHandler {
            onTapped: button.activated()
        }
        HoverHandler {
            id: buttonHover
            cursorShape: Qt.PointingHandCursor
        }
        Tooltip {
            target: button
            edge: "Bottom"
            text: button.tip
            hovered: buttonHover.hovered
        }
    }

    // A button with a name; filled with the accent for the action itself.
    component TextButton: Rectangle {
        id: textButton

        property alias text: label.text
        property bool strong
        signal activated

        anchors.verticalCenter: parent?.verticalCenter
        width: label.width + 28
        height: 36
        radius: Theme.rounded ? 6 : 0
        color: strong ? Theme.accent : Theme.veil(textHover.hovered ? 0.07 : 0)

        Text {
            id: label
            anchors.centerIn: parent
            color: textButton.strong ? "white" : Theme.ink
            font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
        }

        TapHandler {
            onTapped: textButton.activated()
        }
        HoverHandler {
            id: textHover
            cursorShape: Qt.PointingHandCursor
        }
    }

    // What to pick: an icon and its name; the chosen one raised in white.
    component Choice: Rectangle {
        id: choice

        property string text
        property string mode
        property string strokes
        readonly property bool on: Capture.mode === mode

        width: (selectPanel.inner - 12) / 3
        height: 40
        radius: 9
        color: on ? "white" : Theme.veil(choiceHover.hovered ? 0.05 : 0)

        Rectangle {
            visible: choice.on
            anchors.fill: parent
            anchors.topMargin: 1
            z: -1
            radius: parent.radius
            color: Theme.veil(0.12)
        }
        Row {
            anchors.centerIn: parent
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                gridWidth: 20
                gridHeight: 20
                strokeWidth: 1.5
                capStyle: ShapePath.RoundCap
                color: choice.on ? Theme.accent : Theme.inkSoft
                strokes: choice.strokes
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: choice.text
                color: choice.on ? Theme.accent : Theme.ink
                font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
            }
        }

        TapHandler {
            onTapped: window.pickWhat(choice.mode)
        }
        HoverHandler {
            id: choiceHover
            cursorShape: Qt.PointingHandCursor
        }
    }

    // An option beside the switch: an icon and a short name, faint unless
    // on. `tip` says what it is.
    component Option: Rectangle {
        id: option

        property string text
        property string strokes
        property string tip
        property bool on
        signal activated

        width: optionRow.width + 20
        height: 36
        radius: 18
        color: Theme.veil(optionHover.hovered && enabled ? 0.06 : 0)

        Row {
            id: optionRow

            anchors.centerIn: parent
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                height: 16
                gridWidth: 20
                gridHeight: 20
                strokeWidth: 1.6
                capStyle: ShapePath.RoundCap
                color: option.on ? Theme.accent : Theme.inkFaint
                strokes: option.strokes
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: option.text
                color: option.on ? Theme.accent : Theme.inkFaint
                font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
            }
        }

        TapHandler {
            enabled: option.enabled
            onTapped: option.activated()
        }
        HoverHandler {
            id: optionHover
            cursorShape: option.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
        Tooltip {
            target: option
            edge: "Bottom"
            text: option.tip
            hovered: optionHover.hovered
        }
    }

    component Divider: Rectangle {
        anchors.verticalCenter: parent?.verticalCenter
        width: 1
        height: 20
        color: Theme.veil(0.12)
    }
}
