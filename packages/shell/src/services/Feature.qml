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
    // The keyboard shortcuts it answers (Shortcuts.qml): { name: function }.
    property var shortcuts: ({})
}
