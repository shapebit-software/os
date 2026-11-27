import QtQuick

// What a feature adds to the shell, which its package installs in features/
// of the shell's folder as FEATURE.qml (Features.qml), with its own QML as the
// module qs.FEATURE, beside the shell's. The shell names no feature: it shows
// what each one adds.
QtObject {
    // The feature's name: its package's folder.
    property string name
    // Settings' sections, as SettingsWindow.qml's, each with where it goes in
    // the sidebar: { id, name, icon, rows, group, before, after }; a section
    // with a page of its own has `component`, its rows only for the search,
    // and with `wide`, more room.
    property var sections: []
    // Settings' pages: { id: { title, section, rows } }, or a page of its own,
    // { id: { title, section, component } }.
    property var pages: ({})
    // Rows it adds to the shell's sections and pages, or another feature's,
    // after their own: { id: [rows] }, rows as a section's.
    property var rows: ({})
    // What it shows on every screen: each a window, made for each screen as
    // Variants makes them (modelData, the screen).
    property list<Component> surfaces
    // Its panels, which open by a bar's button, made for each screen as the
    // shell's are (Panels.qml), with the screen and its name, screenName.
    property list<Component> panels
    // The keyboard shortcuts it answers (Shortcuts.qml): { name: function }.
    property var shortcuts: ({})
    // Its items for the bars (ShellItem.qml), by the name that Settings.zones
    // keeps: { name: { label, icon, component } }. The component's root takes
    // the item's bar, half, and size.
    property var items: ({})
    // Its quick actions, which the hot corner fans out (HotCorner.qml), in
    // the order of their `order`, the first nearest the screen's right edge:
    // [{ name, icon, order, tap: (screen, rect) => ... }].
    property var actions: []
    // What it records, which the hot corner shows while its buttons are on
    // the bars hidden: { elapsed, stop }, or null.
    property var recording: null
    // Whether banners wait, as while the screen is shared.
    property bool quiet
    // What it hears while it listens, which the hot corner shows: { listening,
    // writing, level }, or null.
    property var voice: null
    // What it does for other features: { name: function }; another asks
    // Features.provided(name).
    property var provides: ({})
    // The portal requests it answers (Portal.qml), by the portal's name:
    // { name: handler }, each with ask(socket, request) and dropped(socket).
    property var portals: ({})

    // A click on a bar off any of its buttons (ShellBar.qml).
    signal clickedOff
}
