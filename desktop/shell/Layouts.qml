// The layouts a workspace can have, as the shell shows them: the compositor
// places the windows (compositor/layouts.lua); these are the names, the icons
// on the layout button, and the pictures in the layout menu, from the demo.
pragma Singleton
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
}
