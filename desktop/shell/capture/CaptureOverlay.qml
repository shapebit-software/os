// The capture overlay (Capture.qml) over one screen, dimmed, with a panel at
// the bottom center in the popovers' light glass, in one row of icons: what
// to pick (a selection, a window, or the screen); a switch between a
// screenshot and a recording whose knob is the capture button; and the
// options of the kind chosen: for screenshots, Edit, which opens them for
// markup before they are saved (Settings.captureMarkup); for recordings, the
// timer, its seconds in a badge, and Mic, which records the microphone
// (Settings.captureMicrophone). Cancel sits on the panel's corner; until
// something is picked, the middle of the screen says what to do. A
// drag draws the selection, which shows its size in pixels, moves when
// dragged from inside, resizes from its corners, and is kept for next time;
// in Window, a click picks the window under the pointer. The capture button
// or Enter captures; Escape cancels.
//
// When an application shares the screen (SharePicker.qml), the panel picks
// what to share: the switch is the Share button instead, and the only option
// is Remember, which lets the application share it again without asking
// (Settings.shareRemember).
//
// With Edit, the screenshot shows for markup (CaptureMarkup.qml), with its
// tools and colors, Delete, Undo, Redo, Copy, and Save; Enter saves.
// Without, the screen flashes where it was taken. During the timer, only the
// countdown shows, and lets clicks through.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.controls
import qs.services

Scope {
    id: overlay

    required property ShellScreen modelData

    readonly property bool here: Capture.screen === modelData
    readonly property bool portal: Capture.request !== null
    readonly property bool sharing: SharePicker.asking
    // Under the compositor's blur threshold for this namespace, so what is
    // dimmed stays sharp (compositor/hyprland.lua).
    readonly property color dim: Qt.rgba(0.05, 0.04, 0.09, 0.45)
    readonly property color red: "#e5484d"
    // A screenshot's symbol, a camera, and a recording's, a video camera.
    readonly property string camera: "M2.75 7.25a1.5 1.5 0 0 1 1.5-1.5h2l1.25-2h5l1.25 2h2a1.5 1.5 0 0 1 1.5 1.5v7.5a1.5 1.5 0 0 1-1.5 1.5H4.25a1.5 1.5 0 0 1-1.5-1.5zM7 10.5a3 3 0 1 0 6 0a3 3 0 1 0-6 0z"
    readonly property string video: "M2.75 6.75a1.5 1.5 0 0 1 1.5-1.5h7a1.5 1.5 0 0 1 1.5 1.5v6.5a1.5 1.5 0 0 1-1.5 1.5h-7a1.5 1.5 0 0 1-1.5-1.5zM12.75 8.75l4.5-2.5v7.5l-4.5-2.5"
    // Sharing's: a screen with an arrow up.
    readonly property string share: "M2.75 3.75h14.5v9.5H2.75zM7 16.25h6M10 13.25v3M10 11V6M7.75 8.25 10 6l2.25 2.25"
    // The capture panel's fill, and the tracks of its controls.
    readonly property color panelFill: Theme.oklch(0.94, 0.006, 285)
    readonly property color track: Theme.oklch(0.885, 0.01, 285)

    PanelWindow {
        id: window

        readonly property bool marking: Capture.stage === "markup"
        // What is picked: the selection drawn, the window clicked, by its
        // address too, or the screen; and what lights up: that, or the
        // window under the pointer.
        property rect picked
        property string pickedWindow
        property rect hovered
        readonly property rect lit: marking ? Capture.area
            : Capture.mode === "Screen" ? whole
            : Capture.mode === "Window" && picked.width === 0 ? hovered : picked
        readonly property bool ready: picked.width >= 4 && picked.height >= 4 || Capture.mode === "Screen"
        // The windows on the screen's workspace: their addresses, and where
        // they are in its coordinates.
        readonly property list<var> windows: Hyprland.toplevels.values
            .filter(t => t.workspace?.active && t.monitor?.name === overlay.modelData.name && t.lastIpcObject.at)
            .map(t => {
                const ipc = t.lastIpcObject;
                return {
                    address: t.address,
                    rect: Qt.rect(ipc.at[0] - overlay.modelData.x, ipc.at[1] - overlay.modelData.y, ipc.size[0], ipc.size[1]),
                };
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
                markup.clear();
                keys.forceActiveFocus();
            }
        }

        // In Window, the focused window is picked to begin with, if it is on
        // this screen.
        function pickWhat(mode: string) {
            const focused = mode === "Window" ? windows.find(w => w.address === Hyprland.activeToplevel?.address) : null;
            Capture.mode = mode;
            picked = mode === "Area" ? Capture.lastArea : focused?.rect ?? Qt.rect(0, 0, 0, 0);
            pickedWindow = focused?.address ?? "";
            hovered = Qt.rect(0, 0, 0, 0);
        }

        function capture() {
            if (!ready)
                return;
            const area = Capture.mode === "Screen" ? whole : picked;
            if (overlay.sharing)
                SharePicker.share(overlay.modelData, Capture.mode, area, pickedWindow);
            else
                Capture.take(area);
        }

        // Whether a point is on the bar or Cancel, whose clicks are their own.
        function onBar(point: point): bool {
            const items = [marking ? markupBar : selectPanel, closer];
            return items.some(i => i.visible && i.contains(i.mapFromItem(null, point.x, point.y)));
        }

        // The window at a point, or none.
        function windowAt(x: real, y: real): var {
            return windows.find(w => x >= w.rect.x && x < w.rect.x + w.rect.width
                && y >= w.rect.y && y < w.rect.y + w.rect.height) ?? null;
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
                } else if (window.marking && (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)) {
                    markup.remove();
                } else if (window.marking && event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_Z && event.modifiers & Qt.ShiftModifier || event.key === Qt.Key_Y)
                        markup.redo();
                    else if (event.key === Qt.Key_Z)
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
                    const at = window.windowAt(mouse.x, mouse.y);
                    window.picked = at?.rect ?? Qt.rect(0, 0, 0, 0);
                    window.pickedWindow = at?.address ?? "";
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
                    window.hovered = window.windowAt(mouse.x, mouse.y)?.rect ?? Qt.rect(0, 0, 0, 0);
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
            text: (Capture.mode === "Window" ? "Click a window" : "Drag to select an area")
                + (overlay.sharing ? " to share" : "")
            color: "white"
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.4)
            font { family: Theme.font; pixelSize: 15; weight: Font.Medium }
        }

        // The panel, one row at the bottom center: what to pick; the switch
        // between a screenshot and a recording whose knob captures; and
        // Edit, or the timer and Mic. When sharing, Share and Remember
        // instead. Cancel sits on its corner.
        Bar {
            id: selectPanel

            visible: !window.marking

            // What to pick: the chosen one raised in white.
            Choice {
                tip: "Selection"
                on: Capture.mode === "Area"
                strokes: "M3.5 7V3.5H7M13 3.5h3.5V7M16.5 13v3.5H13M7 16.5H3.5V13"
                onActivated: window.pickWhat("Area")
            }
            Choice {
                tip: "Window"
                on: Capture.mode === "Window"
                strokes: "M2.75 4.25h14.5v11.5H2.75zM2.75 7.5h14.5"
                onActivated: window.pickWhat("Window")
            }
            Choice {
                tip: "Screen"
                on: Capture.mode === "Screen"
                strokes: "M2.75 3.75h14.5v9.5H2.75zM7 16.25h6M10 13.25v3"
                onActivated: window.pickWhat("Screen")
            }

            Divider {}

            // The switch: a screenshot on the left, a recording on the
            // right. A click on the free side moves the knob there;
            // the knob, with its kind's symbol, captures.
            Rectangle {
                id: kinds

                readonly property real knob: 80

                visible: !overlay.sharing
                width: 136
                height: 52
                radius: 14
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
                        height: 20
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
                    width: kinds.knob - 4
                    height: kinds.height - 8
                    radius: 11
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
                        height: 22
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

            // Share, as wide as the switch, muted until there is something
            // to share.
            Rectangle {
                id: shareButton

                visible: overlay.sharing
                width: 136
                height: 52
                radius: 14
                color: window.ready ? Theme.accent : Theme.oklch(0.68, 0.025, 285)
                scale: shareTap.pressed ? 0.96 : 1

                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on scale { NumberAnimation { duration: 90 } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "white"
                    opacity: shareHover.hovered && window.ready ? 0.12 : 0
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 20
                        gridWidth: 20
                        gridHeight: 20
                        strokeWidth: 1.6
                        capStyle: ShapePath.RoundCap
                        color: "white"
                        strokes: overlay.share
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Share"
                        color: "white"
                        font { family: Theme.font; pixelSize: 14; weight: Font.DemiBold }
                    }
                }
                TapHandler {
                    id: shareTap
                    onTapped: window.capture()
                }
                HoverHandler {
                    id: shareHover
                    cursorShape: window.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }

            Divider {}

            // The options of the kind chosen: markup before saving for
            // screenshots; the timer (none, 3 seconds, or 10) and the
            // microphone for recordings; Remember when sharing.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Option {
                    visible: !overlay.sharing && Capture.record
                    badge: Capture.delay ? `${Capture.delay}` : ""
                    tip: "Timer"
                    on: Capture.delay > 0
                    strokes: "M4.5 11a5.5 5.5 0 1 0 11 0a5.5 5.5 0 1 0-11 0zM10 8v3l2 1.5M8 2.75h4"
                    onActivated: Capture.delay = Capture.delay === 0 ? 3 : Capture.delay === 3 ? 10 : 0
                }
                Option {
                    visible: !overlay.sharing && !Capture.record
                    tip: "Edit before saving"
                    on: Settings.captureMarkup
                    strokes: "M9 4.25H5.25a1.5 1.5 0 0 0-1.5 1.5v9a1.5 1.5 0 0 0 1.5 1.5h9a1.5 1.5 0 0 0 1.5-1.5V11M14 3.5l2.5 2.5L10 12.5H7.5V10z"
                    onActivated: Settings.captureMarkup = !Settings.captureMarkup
                }
                Option {
                    visible: !overlay.sharing && Capture.record
                    tip: "Record the microphone"
                    on: Settings.captureMicrophone
                    strokes: "M7.5 5a2.5 2.5 0 0 1 5 0v5a2.5 2.5 0 0 1-5 0zM4.75 9.5a5.25 5.25 0 0 0 10.5 0M10 14.75v2.5"
                    onActivated: Settings.captureMicrophone = !Settings.captureMicrophone
                }
                Option {
                    visible: overlay.sharing
                    tip: "Let the app share it again without asking"
                    on: Settings.shareRemember
                    strokes: "M3.5 10a6.5 6.5 0 1 0 1.9-4.6M3.25 3v3.25H6.5M10 6.5V10l2.5 1.5"
                    onActivated: Settings.shareRemember = !Settings.shareRemember
                }
            }
        }

        // Cancel, on the bar's top right corner, half outside it.
        Rectangle {
            id: closer

            readonly property Item bar: window.marking ? markupBar : selectPanel

            z: 1
            x: bar.x + bar.width - width / 2
            y: bar.y - height / 2
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

        // Markup: the tools, the colors, Delete, Undo and Redo, and Copy and
        // Save; Cancel sits on its corner.
        Bar {
            id: markupBar

            visible: window.marking

            Repeater {
                model: [
                    { name: "Move", strokes: "M10 2.75v14.5M2.75 10h14.5M7.75 5 10 2.75 12.25 5M7.75 15 10 17.25 12.25 15M5 7.75 2.75 10 5 12.25M15 7.75 17.25 10 15 12.25" },
                    { name: "Arrow", strokes: "M4 16L16 4M9.5 4H16v6.5" },
                    { name: "Highlight", strokes: "M3 17h14M5 13.5l7.5-7.5 2.5 2.5L7.5 16H5z" },
                    { name: "Pixelate", strokes: "M3.5 3.5h13v13h-13zM3.5 7.83h13M3.5 12.17h13M7.83 3.5v13M12.17 3.5v13" },
                    { name: "Number", strokes: "M3.5 10a6.5 6.5 0 1 0 13 0a6.5 6.5 0 1 0-13 0zM8.8 7.8l1.4-1v6.6" },
                    { name: "Text", strokes: "M4.5 5.5V4h11v1.5M10 4v12M8 16h4" },
                ]

                Choice {
                    required property var modelData

                    tip: modelData.name
                    strokes: modelData.strokes
                    on: markup.tool === modelData.name
                    onActivated: {
                        markup.commit();
                        markup.tool = modelData.name;
                    }
                }
            }
            Divider {}
            Repeater {
                model: ["#f05653", "#f5c242", "#3f9cf0", "#1d1a24", "#ffffff"]

                Item {
                    id: swatch

                    required property color modelData
                    readonly property bool current: Qt.colorEqual(markup.ink, modelData)

                    anchors.verticalCenter: parent?.verticalCenter
                    width: 40
                    height: 52

                    // The color chosen, ringed.
                    Rectangle {
                        anchors.centerIn: parent
                        visible: swatch.current
                        width: 32
                        height: 32
                        radius: 16
                        color: "transparent"
                        border.color: Theme.accent
                        border.width: 2
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: swatchHover.hovered && !swatch.current ? 24 : 22
                        height: width
                        radius: width / 2
                        color: swatch.modelData
                        border.color: Theme.veil(0.2)
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
            Option {
                tip: "Delete"
                strokes: "M3.75 5.5h12.5M8 5.5V3.75h4V5.5M5.25 5.5l.75 10.75h8l.75-10.75M8.5 8.5v5M11.5 8.5v5"
                opacity: markup.selected >= 0 ? 1 : 0.4
                onActivated: markup.remove()
            }
            Option {
                tip: "Undo"
                strokes: "M7 4.5 3.5 8l3.5 3.5M3.5 8H12a4 4 0 0 1 0 8H9"
                opacity: markup.history.length || markup.editing ? 1 : 0.4
                onActivated: markup.undo()
            }
            Option {
                tip: "Redo"
                strokes: "M13 4.5 16.5 8 13 11.5M16.5 8H8a4 4 0 0 0 0 8h3"
                opacity: markup.future.length && !markup.editing ? 1 : 0.4
                onActivated: markup.redo()
            }
            Divider {}
            TextButton {
                visible: !overlay.portal
                text: "Copy"
                strokes: "M7.25 7.25h9v9h-9zM12.75 7.25v-3.5h-9v9h3.5"
                onActivated: window.copy()
            }
            TextButton {
                text: overlay.portal ? "Share" : "Save"
                strokes: "M10 3.5v9M6.25 9 10 12.75 13.75 9M3.75 13.5v1.75a1.5 1.5 0 0 0 1.5 1.5h9.5a1.5 1.5 0 0 0 1.5-1.5V13.5"
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

    // A panel at the bottom center, in one row: the capture panel or the
    // markup bar. Rounded always, as the design has it, whatever the
    // windows' corners.
    component Bar: Item {
        id: bar

        default property alias items: barRow.data
        readonly property real padding: 6

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height - (Settings.dock === "Bottom" ? Theme.gap : 28)
        width: barRow.width + 2 * padding
        height: barRow.height + 2 * padding

        RectangularShadow {
            anchors.fill: parent
            offset.y: 8
            blur: 24
            radius: 18
            color: Qt.rgba(0, 0, 0, 0.3)
        }
        Rectangle {
            anchors.fill: parent
            radius: 18
            color: overlay.panelFill
        }
        Row {
            id: barRow

            x: bar.padding
            y: bar.padding
            spacing: 4
        }
    }

    // A button with an icon and a name: raised in white, or filled with the
    // accent for the action itself.
    component TextButton: Rectangle {
        id: textButton

        property alias text: label.text
        property string strokes
        property bool strong
        signal activated

        anchors.verticalCenter: parent?.verticalCenter
        width: content.width + 32
        height: 44
        radius: 12
        color: strong ? (textHover.hovered ? Qt.darker(Theme.accent, 1.08) : Theme.accent)
            : textHover.hovered ? Theme.oklch(0.985, 0.003, 285) : "white"
        scale: textTap.pressed ? 0.96 : 1

        Behavior on scale { NumberAnimation { duration: 90 } }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 1
            z: -1
            radius: parent.radius
            color: textButton.strong ? Qt.darker(Theme.accent, 1.3) : Theme.veil(0.12)
        }
        Row {
            id: content

            anchors.centerIn: parent
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                gridWidth: 20
                gridHeight: 20
                strokeWidth: 1.6
                capStyle: ShapePath.RoundCap
                color: textButton.strong ? "white" : Theme.ink
                strokes: textButton.strokes
            }
            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                color: textButton.strong ? "white" : Theme.ink
                font { family: Theme.font; pixelSize: 14; weight: Font.DemiBold }
            }
        }

        TapHandler {
            id: textTap
            onTapped: textButton.activated()
        }
        HoverHandler {
            id: textHover
            cursorShape: Qt.PointingHandCursor
        }
    }

    // What to pick, or a markup tool: an icon, named by its tooltip; the
    // chosen one raised in white.
    component Choice: Rectangle {
        id: choice

        property string tip
        property string strokes
        property bool on
        signal activated

        width: 52
        height: 52
        radius: 12
        color: on ? "white" : Theme.veil(choiceHover.hovered ? 0.05 : 0)

        Rectangle {
            visible: choice.on
            anchors.fill: parent
            anchors.topMargin: 1
            z: -1
            radius: parent.radius
            color: Theme.veil(0.12)
        }
        Icon {
            anchors.centerIn: parent
            height: 20
            gridWidth: 20
            gridHeight: 20
            strokeWidth: 1.5
            capStyle: ShapePath.RoundCap
            color: choice.on ? Theme.accent : Theme.inkSoft
            strokes: choice.strokes
        }

        TapHandler {
            onTapped: choice.activated()
        }
        HoverHandler {
            id: choiceHover
            cursorShape: Qt.PointingHandCursor
        }
        Tooltip {
            target: choice
            edge: "Bottom"
            text: choice.tip
            hovered: choiceHover.hovered
        }
    }

    // An option, as right of the switch, or Delete, Undo, and Redo: an icon, tinted while on, with its
    // value in a badge when there is one. `tip` says what it is.
    component Option: Rectangle {
        id: option

        property string badge
        property string strokes
        property string tip
        property bool on
        signal activated

        anchors.verticalCenter: parent?.verticalCenter
        width: 44
        height: 44
        radius: 12
        color: on ? Theme.accentSoft : Theme.veil(optionHover.hovered && enabled ? 0.06 : 0)

        Icon {
            anchors.centerIn: parent
            height: 20
            gridWidth: 20
            gridHeight: 20
            strokeWidth: 1.6
            capStyle: ShapePath.RoundCap
            color: option.on ? Theme.accent : Theme.inkSoft
            strokes: option.strokes
        }
        Rectangle {
            visible: option.badge !== ""
            x: parent.width - width + 6
            y: -6
            width: Math.max(height, count.width + 8)
            height: 18
            radius: 9
            color: Theme.accent
            border.color: overlay.panelFill
            border.width: 1.5

            Text {
                id: count
                anchors.centerIn: parent
                text: option.badge
                color: "white"
                font { family: Theme.font; pixelSize: 11; weight: Font.Bold }
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

    // A rule between a bar's groups.
    component Divider: Item {
        width: 13
        height: 52

        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: 24
            color: Theme.veil(0.12)
        }
    }
}
