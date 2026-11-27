// What the app center adds to the shell (packages/shell/src/services/Feature.qml),
// which its package installs as the shell's features/apps.qml, with its QML as
// the module qs.apps beside it: Settings > Apps, to find, install, and remove
// apps, and each app's details, which the Apps panel opens too.
import QtQuick
import qs.apps
import qs.services

Feature {
    name: "apps"
    sections: [
        // Its page is its own (AppsPage.qml); the row is for the search.
        { id: "apps", name: "Apps", icon: "M2.4 2.4h4.4v4.4H2.4zM9.2 2.4h4.4v4.4H9.2zM2.4 9.2h4.4v4.4H2.4zM9.2 9.2h4.4v4.4H9.2z",
          group: 3, before: "downloads", component: store, wide: true, rows: [
            { label: "Apps", detail: "Find, install, and remove apps", value: "Open", open: () => Features.openSection("apps") },
        ] },
    ]
    pages: ({ "app": { title: "App details", section: "apps", component: details } })
    // An app's details, from the Apps panel, asking first if to remove it with
    // `confirming`: { id, name, summary, confirming }.
    provides: ({ "app-details": (screen, app) => {
        Apps.open();
        Apps.show(app);
        Settings.open(screen, "apps");
        Features.openPage("app");
    } })

    property Component store: Component {
        AppsPage {
            onOpened: app => {
                Apps.show(app);
                Features.openPage("app");
            }
        }
    }
    property Component details: Component { AppPage {} }
}
