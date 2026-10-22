// The layouts a workspace can have, as the shell shows them: the compositor
// places the windows (compositor/layouts.lua); these are the names, the icons
// on the layout button, and the pictures in the layout menu, from the demo.
// The pictures follow the compositor's templates, so maps can show where
// windows would go (place).
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // Each picture is a list of columns: [width, [[height, active], ...]].
    readonly property var all: [
        { id: "lead", name: "Lead", icon: "M7 1v10M7 4.3h4M7 7.7h4",
          picture: [[1.7, [[1, true]]], [1, [[1], [1], [1]]]] },
        { id: "dwindle", name: "Dwindle", icon: "M6 1v10M6 6h5",
          picture: [[1, [[1, true]]], [1, [[1], [1]]]] },
        { id: "columns", name: "Columns", icon: "M4.3 1v10M7.7 1v10",
          picture: [[1, [[1, true]]], [1, [[1]]], [1, [[1]]]] },
        { id: "center", name: "Center", icon: "M3.5 1v10M8.5 1v10",
          picture: [[0.5, [[1]]], [2.4, [[1, true]]], [0.5, [[1]]]] },
        { id: "grid", name: "Grid", icon: "M6 1v10M1 6h10",
          picture: [[1, [[1, true], [1]]], [1, [[1], [1]]]] },
        { id: "tabs", name: "Tabs", icon: "M1 3.8h10M4.5 1v2.8M8 1v2.8",
          picture: [[1, [[0.25], [1, true]]]] },
        { id: "rows", name: "Rows", icon: "M1 4.3h10M1 7.7h10",
          picture: [[1, [[1], [1, true], [1]]]] },
        { id: "accordion", name: "Accordion", icon: "M2.8 1v10M4.6 1v10M7.4 1v10M9.2 1v10",
          picture: [[0.3, [[1]]], [0.3, [[1]]], [1, [[1, true]]], [0.3, [[1]]], [0.3, [[1]]]] },
    ]

    function byId(id: string): var {
        return all.find(l => l.id === id) ?? all[0];
    }

    // Whether a layout suits a workspace with `count` windows, as in the
    // demo: Grid needs four, and the layouts around a large window three.
    function suits(id: string, count: int): bool {
        if (id === "grid")
            return count >= 4;
        if (["lead", "dwindle", "center", "accordion"].includes(id))
            return count >= 3;
        return true;
    }

    // Where a layout puts `count` windows in a width × height area, as the
    // compositor does: one rectangle per window, in the order windows fill
    // the cells. The pictures are the compositor's templates. Tabs and
    // Accordion show one window at a time, so for maps they put the first
    // window large and the others beside it, as the demo does.
    function place(id: string, count: int, width: real, height: real): list<rect> {
        if (count < 1)
            return [];
        const template = id === "tabs" || id === "accordion"
            ? (count === 1 ? [[1, [[1, true]]]] : [[1.5, [[1, true]]], [1, Array(count - 1).fill([1])]])
            : id === "grid" && count <= 2 ? [[1, [[1, true]]], [1, [[1]]]] : byId(id).picture;
        // The cells, and again with the active one first.
        const slots = [], ranked = [];
        template.forEach(([, cells], column) => cells.forEach(([height, active]) => {
            const slot = { column, height, window: -1 };
            slots.push(slot);
            ranked.splice(active ? 0 : ranked.length, 0, slot);
        }));
        ranked.forEach((slot, i) => slot.window = i < count ? i : -1);
        // Columns without windows go away; windows beyond the cells join the
        // last column.
        const used = [];
        template.forEach(([weight], column) => {
            const cells = slots.filter(s => s.column === column && s.window >= 0);
            if (cells.length)
                used.push({ weight, cells });
        });
        for (let i = slots.length; i < count; i++)
            used[used.length - 1].cells.push({ height: 1, window: i });

        const split = (length, weights) => {
            const total = weights.reduce((a, b) => a + b, 0);
            let at = 0;
            return weights.map(w => {
                const part = [at, length * w / total];
                at += part[1];
                return part;
            });
        };
        const rects = [];
        split(width, used.map(c => used.length === 1 ? 1 : c.weight)).forEach(([x, w], c) => {
            const cells = used[c].cells;
            split(height, cells.map(s => s.height)).forEach(([y, h], k) => rects[cells[k].window] = Qt.rect(x, y, w, h));
        });
        return rects;
    }
}
