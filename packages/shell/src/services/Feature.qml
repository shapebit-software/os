import QtQuick

// What a feature adds to the shell, which its package installs in features/
// of the shell's folder as FEATURE.qml (Features.qml), with its own QML as the
// module qs.FEATURE, beside the shell's. The shell names no feature: it shows
// what each one adds.
QtObject {
    // The feature's name: its package's folder.
    property string name
    // Settings' sections, as SettingsWindow.qml's, each with where it goes in
    // the sidebar: { id, name, icon, rows, own, group, after }.
    property var sections: []
    // Settings' pages: { id: { title, section, rows } }, or a page of its own,
    // { id: { title, section, component } }.
    property var pages: ({})
    // What it shows on every screen: each a window, made for each screen as
    // Variants makes them (modelData, the screen).
    property list<Component> surfaces
    // Its panels, which open by a bar's button, made for each screen as the
    // shell's are (Panels.qml), with the screen and its name, screenName.
    property list<Component> panels
    // The keyboard shortcuts it answers (Shortcuts.qml): { name: function }.
    property var shortcuts: ({})
    // Its items for the bars (ShellItem.qml), by the name that Settings.zones
    // keeps: { name: { icon, component } }. The component's root takes the
    // item's bar, half, and size.
    property var items: ({})
    // Its quick actions, which the hot corner fans out (HotCorner.qml):
    // [{ name, icon, tap: (screen, rect) => ... }].
    property var actions: []
    // What it hears while it listens, which the hot corner shows: { listening,
    // writing, level }, or null.
    property var voice: null
    // What it does for other features: { name: function }; another asks
    // Features.provided(name).
    property var provides: ({})

    // A click on a bar off any of its buttons (ShellBar.qml).
    signal clickedOff
}
