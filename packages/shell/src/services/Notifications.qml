// The notification server: applications' notifications, kept until they are
// dismissed, grouped by application (NotificationsPanel.qml), and shown as
// banners while new (NotificationBanners.qml). The rules are notifications.js:
// each application's notifications show as banners, only stay in the center,
// or are dropped (Settings.notificationApps); low ones show no banner; and
// while it is quiet, with Do Not Disturb or the screen shared, only critical
// ones do. The rest are kept all the same, and one banner counts them when
// the quiet ends. They are kept over a reload of the shell, not over the
// session's end, when the applications that answer them are gone. The shell
// posts its own as applications do (post), naming what opening one opens, and
// tells of a download or an install that failed.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "notifications.js" as Rules

Singleton {
    id: notifications

    // Newest first.
    readonly property list<Notification> all: [...server.trackedNotifications.values].reverse()
    // By application: [{ key, name, items }] (notifications.js).
    readonly property var groups: Rules.groups(all)
    // Those waiting as banners, newest first: the first few show, the rest
    // are counted.
    property list<Notification> banners
    readonly property list<Notification> shownBanners: banners.slice(0, Rules.maxBanners)
    readonly property int moreBanners: banners.length - shownBanners.length
    // Whether any came since the panel was last open.
    property bool unseen
    // Whether the bell shows (ShellItem.qml): always, if set so, or while
    // there is anything for it to show: a notification, a download, Do Not
    // Disturb, or its own panel, open.
    readonly property bool present: Settings.bell === "Always" || all.length > 0 || Downloads.busy || Settings.doNotDisturb
        || Shell.panel === "notifications"

    // Banners are held back, except critical ones, and how many were since.
    readonly property bool quiet: Settings.doNotDisturb || SharePicker.sharing
    property int held
    readonly property list<string> quietChoices: Rules.quietChoices
    readonly property list<string> modes: Rules.modes
    // The applications that have sent one: [{ key, name, mode }], by name.
    readonly property var apps: Rules.list(Settings.notificationApps)

    // How long a banner stays, unless the application says.
    readonly property int bannerTime: 5000
    // Where the banners show: { top, side }, nearest the bell.
    readonly property var corner: {
        const place = Shell.find("notifications");
        return Rules.corner(place?.bar ? Shell.edgeOf(place.bar) : "", place?.zone ?? "");
    }

    readonly property string focused: Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? ""

    // Posts one of the shell's own. Opening it opens `target`: "welcome",
    // "notifications", or a section of Settings as "settings:downloads". A
    // transient one is only a banner, and is not kept.
    function post(app: string, icon: string, summary: string, body: string, target: string, transient: bool) {
        Quickshell.execDetached(["gdbus", "call", "--session",
            "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications",
            "--method", "org.freedesktop.Notifications.Notify", app, "0", icon, summary, body,
            "['default', 'Open']", `{'x-shell-open': <'${target}'>, 'transient': <${transient}>}`, "0"]);
    }

    function hideBanner(notification: Notification) {
        banners = banners.filter(n => n !== notification);
        if (notification.transient)
            notification.expire();
    }

    // The panel is open: what waits as a banner has been seen there, except
    // critical ones, which stay until dismissed.
    function seen() {
        unseen = false;
        const gone = banners.filter(n => n.urgency !== NotificationUrgency.Critical);
        banners = banners.filter(n => !gone.includes(n));
        for (const notification of gone.filter(n => n.transient))
            notification.expire();
    }

    // Opens what the notification is about: the shell's own target, or the
    // application's default action.
    function open(notification: Notification) {
        const target = String(notification.hints["x-shell-open"] ?? "");
        if (target) {
            if (target === "welcome")
                Settings.welcome();
            else if (target === "notifications")
                Shell.request("notifications", focused);
            else if (target.startsWith("settings:"))
                Settings.open(focused, target.slice(9));
            notification.dismiss();
            return;
        }
        // Quickshell does not declare the actions' type to tooling.
        const action = notification.actions.find(a => a.identifier === "default"); // qmllint disable unresolved-type
        if (action)
            action.invoke();
        else
            notification.dismiss();
    }

    function clear() {
        for (const notification of all)
            notification.dismiss();
    }

    // Clears one application's.
    function clearGroup(key: string) {
        for (const notification of all.filter(n => Rules.keyOf(n) === key))
            notification.dismiss();
    }

    function modeOf(key: string): string {
        return Rules.modeOf(Settings.notificationApps, key);
    }

    // `name` names an application that has sent none yet.
    function setMode(key: string, mode: string, name: string) {
        Settings.notificationApps = Rules.setMode(Settings.notificationApps, key, mode, name);
    }

    // Turns Do Not Disturb on, for one of quietChoices, or off.
    function setQuiet(choice: string) {
        Settings.doNotDisturbUntil = Rules.quietUntil(choice, Date.now());
        Settings.doNotDisturb = choice !== "";
    }

    // Says once how many were held back, when the quiet ends.
    onQuietChanged: {
        if (quiet || held === 0)
            return;
        post("Notifications", "", held === 1 ? "1 new notification" : `${held} new notifications`,
            "Held back while Do Not Disturb was on or the screen was shared.", "notifications", true);
        held = 0;
    }

    Timer {
        interval: 15000
        repeat: true
        triggeredOnStart: true
        running: Settings.doNotDisturb && Settings.doNotDisturbUntil > 0
        onTriggered: {
            if (Rules.quietOver(Settings.doNotDisturbUntil, Date.now()))
                notifications.setQuiet("");
        }
    }

    // A download or an install that failed: opening it opens Settings >
    // Downloads, which can try again.
    Connections {
        target: Downloads

        function onEnded(job: var) {
            if (job.state === "failed")
                notifications.post("Downloads", "folder-download",
                    `Couldn't ${job.action === "remove" ? "remove" : job.kind === "update" ? "update" : "install"} ${job.name}`,
                    job.error ?? "", "settings:downloads", false);
        }
    }

    NotificationServer {
        id: server

        bodySupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: true

        onNotification: notification => {
            const key = Rules.keyOf(notification);
            const apps = Settings.notificationApps;
            if (!Rules.keeps(apps, key))
                return;
            const urgency = notification.urgency === NotificationUrgency.Low ? Rules.low
                : notification.urgency === NotificationUrgency.Critical ? Rules.critical : 1;
            // One kept from before a reload has had its banner.
            const banner = !notification.lastGeneration && Rules.banners(apps, key, urgency, notifications.quiet);
            if (notification.transient && !banner)
                return;
            notification.tracked = true;
            notification.closed.connect(() => {
                notifications.banners = notifications.banners.filter(n => n !== notification);
            });
            if (notification.lastGeneration)
                return;
            if (!notification.transient) {
                notifications.unseen = true;
                const known = Rules.remember(apps, key, notification.appName);
                if (known)
                    Settings.notificationApps = known;
            }
            if (banner)
                notifications.banners = [notification, ...notifications.banners];
            else if (Rules.held(apps, key, urgency, notifications.quiet))
                notifications.held += 1;
        }
    }
}
