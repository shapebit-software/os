pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "features.js" as Merge

// The features that the shell shows: each FEATURE.qml in features/ of the
// shell's folder, a Feature, which the feature's package installs. The shell
// merges what they add with its own (features.js).
Singleton {
    id: root

    // The features, loaded.
    property list<QtObject> list
    readonly property var pageComponents: Merge.pageComponents(list)
    readonly property var shortcuts: Merge.shortcuts(list)
    readonly property var surfaces: [].concat(...list.map(f => Array.from(f.surfaces)))
    readonly property var panels: [].concat(...list.map(f => Array.from(f.panels)))
    readonly property var items: Merge.items(list)
    readonly property var actions: Merge.actions(list)
    readonly property var portals: Merge.portals(list)
    // What a feature hears while it listens, the first that does, or null.
    readonly property var voice: list.map(f => f.voice).find(v => v) ?? null
    // What a feature records, the first that does, or null.
    readonly property var recording: list.map(f => f.recording).find(r => r) ?? null
    // Whether a feature holds banners back.
    readonly property bool quiet: list.some(f => f.quiet)

    // What a feature does for others (Feature.provides), or null.
    function provided(name) {
        return Merge.provided(list, name);
    }

    // Settings shows a page of a feature's, such as from a row of its section,
    // or a section.
    signal pageAsked(string id)
    signal sectionAsked(string id)

    function openPage(id) {
        pageAsked(id);
    }

    function openSection(id) {
        sectionAsked(id);
    }

    // A click on a bar off any of its buttons, which features hear.
    function clickedOff() {
        for (const feature of list)
            feature.clickedOff();
    }

    function sections(own) {
        return Merge.sections(own, list);
    }

    function groups(own) {
        return Merge.groups(own, list);
    }

    function pages(own) {
        return Merge.pages(own, list);
    }

    function pageRows(own) {
        return Merge.pageRows(own, list);
    }

    // Loads the features that the folder lists, once it has read it; one
    // that fails to load says why in the journal, and the others still load.
    function load() {
        const loaded = [];
        for (let i = 0; i < folder.count; i++) {
            const url = folder.get(i, "fileUrl");
            const component = Qt.createComponent(url);
            const feature = component.status === Component.Ready ? component.createObject(root) : null;
            if (feature)
                loaded.push(feature);
            else
                console.warn(`Features: ${url}: ${component.errorString()}`);
        }
        list = loaded;
    }

    FolderListModel {
        id: folder

        folder: Qt.resolvedUrl("../features")
        nameFilters: ["*.qml"]
        showDirs: false
        sortField: FolderListModel.Name
        onStatusChanged: if (status === FolderListModel.Ready)
            root.load()
    }
}
