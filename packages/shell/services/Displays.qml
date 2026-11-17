// The displays, and their settings (Settings.qml): each one's mode and
// scale, where it is beside the others, which other display it mirrors, and
// the primary display, where the session starts, with its first workspace
// and the pointer. The settings are the compositor's monitor rules, applied
// as they change and kept in ~/.config/desktop/displays.lua, which the
// compositor runs as it starts (compositor/hyprland.lua), so that the session
// starts with them.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: displays

    // Every display, mirrors included: { name, label, id, x, y, w, h, width,
    // height, scale, transform, rate, modes, mirrorOf }: the position and the
    // size, w and h, in the compositor's coordinates, and the mode's size in
    // pixels; modes as { size, rate }, such as { size: "2560x1600", rate: 120 };
    // mirrorOf a display's name or "".
    property var all: []
    // Those beside each other, which are not mirrors.
    readonly property var arranged: all.filter(d => !d.mirrorOf)
    // The primary display: the one chosen, or else the first.
    readonly property string primary: arranged.some(d => d.name === Settings.primary) ? Settings.primary
        : [...arranged].sort((a, b) => a.id - b.id)[0]?.name ?? ""

    // The settings as the compositor's rules. A display that mirrors none
    // has mirror = "", which ends mirroring; the rule for workspace 1 replaces
    // the one before it.
    readonly property string rules: {
        const names = Object.keys(Object.assign({}, Settings.scales, Settings.modes, Settings.positions, Settings.mirrors));
        const monitors = names.map(name => `hl.monitor({ output = ${Compositor.quote(name)}, mode = ${Compositor.quote(Settings.modes[name] ?? "preferred")}, `
            + `position = ${Compositor.quote(Settings.positions[name] ?? "auto")}, scale = ${Settings.scales[name] ?? '"auto"'}, `
            + `mirror = ${Compositor.quote(Settings.mirrors[name] ?? "")} })`);
        const primary = Settings.primary ? [
            "if displays and displays.primary then displays.primary:set_enabled(false) end",
            `displays = { primary = hl.workspace_rule({ workspace = "1", monitor = ${Compositor.quote(Settings.primary)}, default = true }) }`,
            `hl.config({ cursor = { default_monitor = ${Compositor.quote(Settings.primary)} } })`,
        ] : [];
        return [...monitors, ...primary].join("\n");
    }

    function byName(name: string): var {
        return all.find(d => d.name === name) ?? null;
    }

    // As the settings load (Settings.apply), and then on every change.
    function apply() {
        if (rules)
            Compositor.dispatch(`function()\n${rules}\nend`);
        const text = `-- Settings > Display, written by the shell (Displays.qml); changes here are replaced.\n${rules}\n`;
        if (file.text() !== text)
            file.setText(text);
        // The compositor's changes take a moment.
        later.restart();
    }

    onRulesChanged: apply()

    function setScale(name: string, scale: real) {
        const display = byName(name);
        if (display)
            resize(display, display.width, display.height, scale);
        Settings.scales = Object.assign({}, Settings.scales, { [name]: scale });
    }

    // A mode such as "2560x1600@120".
    function setMode(name: string, mode: string) {
        const display = byName(name);
        const [width, height] = mode.split("@")[0].split("x").map(Number);
        if (display)
            resize(display, width, height, display.scale);
        Settings.modes = Object.assign({}, Settings.modes, { [name]: mode });
    }

    // When a display that has a place changes size, to width, height in
    // pixels at a scale, those beyond its right or bottom edge move with that
    // edge, so that they stay beside it.
    function resize(display: var, width: int, height: int, scale: real) {
        if (!(display.name in Settings.positions) || display.mirrorOf)
            return;
        const [w, h] = display.transform % 2 ? [height, width] : [width, height];
        const dx = Math.round(w / scale - display.w), dy = Math.round(h / scale - display.h);
        const places = arranged.filter(d => d !== display).map(d => ({ name: d.name,
            x: d.x >= display.x + display.w ? d.x + dx : d.x,
            y: d.y >= display.y + display.h ? d.y + dy : d.y }));
        place([...places, { name: display.name, x: display.x, y: display.y }]);
    }

    // Puts a display at a place, such as snap() found, and every display
    // where it is, the top left one at 0, 0. The others join it one by one,
    // the nearest first: where they are if they touch one that has joined,
    // or else against the nearest edge of those, so that the pointer can go
    // to every display.
    function move(name: string, x: int, y: int) {
        const moved = byName(name);
        const places = [{ name, x, y, w: moved.w, h: moved.h }];
        const rest = arranged.filter(d => d.name !== name).map(d => ({ name: d.name, x: d.x, y: d.y, w: d.w, h: d.h }));
        while (rest.length) {
            rest.sort((a, b) => apart(a, places) - apart(b, places));
            const next = rest.shift();
            if (apart(next, places) > 0)
                Object.assign(next, snapTo(places, next.x, next.y, next.w, next.h, 0) ?? {});
            places.push(next);
        }
        place(places);
    }

    // How far a display is from the nearest of others; 0 when they share
    // part of an edge.
    function apart(display: var, others: var): real {
        return Math.min(...others.map(o => {
            const dx = Math.max(o.x - display.x - display.w, display.x - o.x - o.w, 0);
            const dy = Math.max(o.y - display.y - display.h, display.y - o.y - o.h, 0);
            const across = Math.min(display.x + display.w, o.x + o.w) - Math.max(display.x, o.x);
            const down = Math.min(display.y + display.h, o.y + o.h) - Math.max(display.y, o.y);
            return dx === 0 && down > 0 || dy === 0 && across > 0 ? 0 : Math.hypot(dx, dy) + 1;
        }));
    }

    function place(places: var) {
        const left = Math.min(...places.map(p => p.x)), top = Math.min(...places.map(p => p.y));
        const positions = Object.assign({}, Settings.positions);
        for (const p of places)
            positions[p.name] = `${p.x - left}x${p.y - top}`;
        Settings.positions = positions;
    }

    // Where a display of size w, h dragged to x, y goes: against the nearest
    // edge of another display, sharing at least a quarter of it, its sides
    // lined up with that display's within `pull`; or nowhere, null, when
    // every such place overlaps a display.
    function snap(name: string, x: real, y: real, w: real, h: real, pull: real): var {
        return snapTo(arranged.filter(d => d.name !== name), x, y, w, h, pull);
    }

    function snapTo(others: var, x: real, y: real, w: real, h: real, pull: real): var {
        const overlaps = (px, py) => others.some(o => px < o.x + o.w && px + w > o.x && py < o.y + o.h && py + h > o.y);
        const along = (at, size, start, length) => {
            const share = Math.min(size, length) / 4;
            const clamped = Math.max(start - size + share, Math.min(start + length - share, at));
            const lines = [start, start + length - size, start + (length - size) / 2];
            return lines.find(line => Math.abs(line - clamped) < pull) ?? clamped;
        };
        let best = null;
        for (const o of others) {
            const ay = along(y, h, o.y, o.h), ax = along(x, w, o.x, o.w);
            for (const [px, py] of [[o.x - w, ay], [o.x + o.w, ay], [ax, o.y - h], [ax, o.y + o.h]]) {
                const distance = Math.hypot(px - x, py - y);
                if (!overlaps(px, py) && (!best || distance < best.distance))
                    best = { x: Math.round(px), y: Math.round(py), distance };
            }
        }
        return best;
    }

    // Mirrors a display on another, or ends that with "". A display that
    // others mirror passes them on to the one it mirrors; one that stops
    // mirroring goes to the right of the others.
    function setMirror(name: string, of: string) {
        const mirrors = Object.assign({}, Settings.mirrors);
        if (of) {
            mirrors[name] = of;
            for (const other in mirrors)
                if (mirrors[other] === name)
                    mirrors[other] = of;
            if (Settings.primary === name)
                Settings.primary = of;
        } else {
            delete mirrors[name];
            const display = byName(name);
            if (display && arranged.length) {
                const right = arranged.reduce((a, b) => a.x + a.w >= b.x + b.w ? a : b);
                place([...arranged.map(d => ({ name: d.name, x: d.x, y: d.y })),
                    { name, x: right.x + right.w, y: right.y }]);
            }
        }
        Settings.mirrors = mirrors;
    }

    function setPrimary(name: string) {
        Settings.primary = name;
    }

    // hyprctl lists mirrors too, unlike Quickshell's Hyprland.monitors.
    Process {
        id: list

        command: ["hyprctl", "monitors", "all", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const monitors = JSON.parse(text).filter(m => !m.disabled);
                const named = id => monitors.find(m => String(m.id) === String(id))?.name ?? "";
                const labels = monitors.map(m => /^(eDP|LVDS|DSI)-/.test(m.name) ? "Built-in display"
                    : `${m.make} ${m.model}`.trim() || m.description || m.name);
                displays.all = monitors.map((m, i) => {
                    const turned = m.transform % 2 === 1;
                    return {
                        name: m.name,
                        label: labels.indexOf(labels[i]) === labels.lastIndexOf(labels[i]) ? labels[i] : `${labels[i]} (${m.name})`,
                        id: m.id, x: m.x, y: m.y, width: m.width, height: m.height, scale: m.scale, transform: m.transform,
                        w: Math.round((turned ? m.height : m.width) / m.scale),
                        h: Math.round((turned ? m.width : m.height) / m.scale),
                        rate: Math.round(m.refreshRate),
                        modes: m.availableModes.map(mode => {
                            const [size, rate] = mode.replace(/Hz$/, "").split("@");
                            return { size, rate: Math.round(parseFloat(rate)) };
                        }),
                        mirrorOf: m.mirrorOf === "none" ? "" : named(m.mirrorOf),
                    };
                });
            }
        }
    }

    // Displays come and go, and change, through the compositor.
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            if (event.name.startsWith("monitor") || event.name === "configreloaded")
                list.running = true;
        }
    }

    Timer {
        id: later
        interval: 600
        onTriggered: list.running = true
    }

    FileView {
        id: file
        path: Settings.directory + "/displays.lua"
        blockLoading: true
    }
}
