// The list of keyboard shortcuts (Super+/; Shortcuts.qml), over everything
// with the screens dimmed: a keyboard with what each key does with the
// modifiers chosen above it, the media keys above it, and the whole shortcut
// of the key under the pointer below it. Holding modifiers chooses them too,
// and they stay chosen when let go. Escape closes it.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.controls
import qs.services

PanelWindow {
    id: window

    required property ShellScreen modelData

    readonly property bool here: Shortcuts.listOn === (modelData?.name ?? "")
    // The modifiers chosen, in the order of `order`.
    property list<string> held: ["Super"]
    readonly property list<string> order: ["Super", "Ctrl", "Alt", "Shift"]
    // The modifiers held down now.
    property var down: ({})
    // Every combination of modifiers with shortcuts, in the order of
    // `preferred`, then any others.
    readonly property list<string> preferred: ["Super", "Super+Shift", "Super+Alt", "Super+Alt+Shift", "Alt", "Alt+Shift", "Ctrl+Alt", "Shift", ""]
    readonly property var combinations: {
        const seen = [];
        for (const shortcut of Shortcuts.all) {
            const name = shortcut.mods.join("+");
            if (!seen.includes(name))
                seen.push(name);
        }
        const rank = name => preferred.includes(name) ? preferred.indexOf(name) : preferred.length;
        return seen.sort((a, b) => rank(a) - rank(b));
    }
    readonly property var shown: Shortcuts.all.filter(s => s.mods.join("+") === held.join("+"))
    // The key under the pointer.
    property var hovered: null

    // A key: its code, the label on it, its width in keys, and the names
    // shortcuts give it; or a gap, with no code.
    function key(code, label, width, names): var {
        return { code, label, width: width ?? 1, names: (names ?? [label]).map(n => n.toLowerCase()) };
    }

    function gap(width): var {
        return { code: -1, label: "", width, names: [] };
    }

    readonly property var rows: [
        [key(9, "Esc"), gap(0.5), ...[67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 95, 96].map((c, i) => key(c, `F${i + 1}`)),
            gap(0.5), key(107, "Print", 1, ["Print"]), key(78, "Scroll", 1, ["Scroll_Lock"]), key(127, "Pause")],
        [key(49, "`", 1, ["grave"]), ..."1234567890".split("").map((c, i) => key(10 + i, c)), key(20, "-", 1, ["minus"]),
            key(21, "=", 1, ["equal"]), key(22, "Backspace", 2, ["BackSpace"]), gap(0.5),
            key(118, "Insert"), key(110, "Home"), key(112, "PgUp", 1, ["Prior", "Page_Up"])],
        [key(23, "Tab", 1.5), ..."QWERTYUIOP".split("").map((c, i) => key(24 + i, c)), key(34, "[", 1, ["bracketleft"]),
            key(35, "]", 1, ["bracketright"]), key(51, "\\", 1.5, ["backslash"]), gap(0.5),
            key(119, "Delete"), key(115, "End"), key(117, "PgDn", 1, ["Next", "Page_Down"])],
        [key(66, "Caps", 1.75, ["Caps_Lock"]), ..."ASDFGHJKL".split("").map((c, i) => key(38 + i, c)),
            key(47, ";", 1, ["semicolon"]), key(48, "'", 1, ["apostrophe"]), key(36, "Enter", 2.25, ["Return"])],
        [key(50, "Shift", 2.25, ["Shift_L"]), ..."ZXCVBNM".split("").map((c, i) => key(52 + i, c)),
            key(59, ",", 1, ["comma"]), key(60, ".", 1, ["period"]), key(61, "/", 1, ["slash"]),
            key(62, "Shift", 2.75, ["Shift_R"]), gap(1.5), key(111, "↑", 1, ["up"])],
        [key(37, "Ctrl", 1.25, ["Control_L"]), key(133, "Super", 1.25, ["Super_L"]), key(64, "Alt", 1.25, ["Alt_L"]),
            key(65, "Space", 6.25, ["space"]), key(108, "Alt", 1.25, ["Alt_R"]), key(134, "Super", 1.25, ["Super_R"]),
            key(135, "Menu"), key(105, "Ctrl", 1.25, ["Control_R"]), gap(0.5),
            key(113, "←", 1, ["left"]), key(116, "↓", 1, ["down"]), key(114, "→", 1, ["right"])],
    ]
    readonly property var mediaKeys: [
        key(122, "Vol −", 1, ["XF86AudioLowerVolume"]), key(123, "Vol +", 1, ["XF86AudioRaiseVolume"]),
        key(121, "Mute", 1, ["XF86AudioMute"]), key(198, "Mic", 1, ["XF86AudioMicMute"]), gap(0.5),
        key(173, "Prev", 1, ["XF86AudioPrev"]), key(172, "Play", 1, ["XF86AudioPlay"]), key(171, "Next", 1, ["XF86AudioNext"]),
        gap(0.5), key(232, "Light −", 1, ["XF86MonBrightnessDown"]), key(233, "Light +", 1, ["XF86MonBrightnessUp"]),
    ]
    // Which modifier each modifier key is.
    readonly property var modifierOf: ({ 37: "Ctrl", 105: "Ctrl", 133: "Super", 134: "Super", 64: "Alt", 108: "Alt", 50: "Shift", 62: "Shift" })

    function shortcutOf(key: var): var {
        return key.code < 0 ? null : shown.find(s => s.code === key.code || key.names.includes((s.key ?? "").toLowerCase())) ?? null;
    }

    function choose(name: string) {
        held = name ? name.split("+") : [];
    }

    // Held modifiers, as Qt names their keys.
    function modifierOfKey(qtKey: int): string {
        return ({ [Qt.Key_Meta]: "Super", [Qt.Key_Super_L]: "Super", [Qt.Key_Super_R]: "Super", [Qt.Key_Control]: "Ctrl",
            [Qt.Key_Alt]: "Alt", [Qt.Key_AltGr]: "Alt", [Qt.Key_Shift]: "Shift" })[qtKey] ?? "";
    }

    function press(qtKey: int, pressed: bool) {
        const name = modifierOfKey(qtKey);
        if (!name)
            return;
        const now = Object.assign({}, down);
        if (pressed)
            now[name] = true;
        else
            delete now[name];
        down = now;
        const names = order.filter(m => now[m]);
        if (names.length > 0)
            held = names;
    }

    visible: here
    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shortcuts"
    WlrLayershell.keyboardFocus: here ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    onHereChanged: {
        if (!here)
            return;
        held = ["Super"];
        down = {};
        keys.forceActiveFocus();
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.05, 0.04, 0.09, 0.45)

        TapHandler {
            onTapped: Shortcuts.listOn = ""
        }
    }

    Item {
        id: keys

        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                Shortcuts.listOn = "";
            window.press(event.key, true);
            event.accepted = true;
        }
        Keys.onReleased: event => {
            window.press(event.key, false);
            event.accepted = true;
        }
    }

    PopoverFrame {
        id: frame

        // Smaller on small screens, so the keyboard fits.
        readonly property real natural: board.width + 2 * padding

        anchors.centerIn: parent
        padding: 20
        scale: Math.min(1, window.width * 0.94 / natural, window.height * 0.94 / (board.height + 2 * padding))

        // Clicks on the list stay in it.
        TapHandler {}

        Column {
            id: board

            readonly property int unit: 56

            spacing: 14

            // The title, and the combinations of modifiers to choose from.
            Row {
                spacing: 6

                Text {
                    width: 200
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Keyboard shortcuts"
                    color: Theme.ink
                    font { family: Theme.font; pixelSize: 16; weight: Font.DemiBold }
                }
                Repeater {
                    model: window.combinations

                    Rectangle {
                        id: chip

                        required property string modelData
                        readonly property bool chosen: window.held.join("+") === modelData

                        width: chipText.width + 20
                        height: 26
                        radius: Theme.rounded ? 13 : 0
                        color: chosen ? Theme.accent : chipHover.hovered ? Theme.veil(0.1) : Theme.veil(0.05)

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData || "No modifier"
                            color: chip.chosen ? "white" : Theme.ink
                            font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
                        }
                        HoverHandler {
                            id: chipHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: window.choose(chip.modelData)
                        }
                    }
                }
            }

            KeyRow {
                keys: window.mediaKeys
            }

            Column {
                spacing: 0

                Repeater {
                    model: window.rows

                    KeyRow {
                        required property var modelData

                        keys: modelData
                    }
                }
            }

            // The whole shortcut of the key under the pointer.
            Text {
                readonly property var shortcut: window.hovered ? window.shortcutOf(window.hovered) : null

                height: 18
                text: shortcut ? `${[...shortcut.mods, window.hovered.label].join("+")}  —  ${shortcut.description}`
                    : "Hold modifiers, or choose them above, to see what the keys do with them."
                color: shortcut ? Theme.ink : Theme.inkFaint
                font { family: Theme.font; pixelSize: 13 }
            }
        }
    }

    component KeyRow: Row {
        id: row

        required property var keys

        Repeater {
            model: row.keys

            Item {
                id: cap

                required property var modelData
                readonly property var shortcut: window.shortcutOf(modelData)
                readonly property bool held: window.held.includes(window.modifierOf[modelData.code] ?? "")

                width: modelData.width * board.unit
                height: board.unit

                Rectangle {
                    anchors { fill: parent; margins: 2 }
                    visible: cap.modelData.code >= 0
                    radius: Theme.rounded ? 6 : 0
                    color: cap.held ? Theme.accent : cap.shortcut ? Theme.accentSoft : Theme.veil(0.05)
                    border.width: cap.shortcut ? 1 : 0
                    border.color: Theme.accent

                    Text {
                        x: 6
                        y: 4
                        text: cap.modelData.label
                        color: cap.held ? "white" : Theme.inkFaint
                        font { family: Theme.mono; pixelSize: 10; weight: Font.DemiBold }
                    }
                    Text {
                        x: 5
                        width: parent.width - 10
                        anchors { bottom: parent.bottom; bottomMargin: 4 }
                        visible: cap.shortcut !== null
                        text: cap.shortcut?.description ?? ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        lineHeight: 0.9
                        color: Theme.ink
                        font { family: Theme.font; pixelSize: 9; weight: Font.Medium }
                    }
                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered)
                                window.hovered = cap.modelData;
                            else if (window.hovered === cap.modelData)
                                window.hovered = null;
                        }
                    }
                }
            }
        }
    }
}
