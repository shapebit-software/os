// The notification server: applications' notifications, kept until they are
// dismissed (NotificationsPanel.qml), and shown as banners while new
// (NotificationBanners.qml). Do Not Disturb (Settings) holds banners back,
// except critical ones; the notifications are kept all the same. The shell
// posts its own as applications do (post), and does what opening one asks
// itself, since it cannot hear back from itself over D-Bus.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: notifications

    // Newest first.
    readonly property list<Notification> all: [...server.trackedNotifications.values].reverse()
    // Those shown as banners, newest first.
    property list<Notification> banners
    // Whether any came since the panel was last open.
    property bool unseen

    // How long a banner stays, unless the application says.
    readonly property int bannerTime: 5000
    // What opening the shell's own notifications does, by their ids.
    property var opens: ({})

    // Posts one of the shell's own: opening it calls onOpen, then dismisses it.
    function post(app: string, icon: string, summary: string, body: string, onOpen: var) {
        poster.createObject(notifications, { onOpen: onOpen, command: ["gdbus", "call", "--session",
            "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications",
            "--method", "org.freedesktop.Notifications.Notify", app, "0", icon, summary, body,
            "['default', 'Open']", "{}", "0"] });
    }

    function hideBanner(notification: Notification) {
        banners = banners.filter(n => n !== notification);
    }

    // Opens what the notification is about, through its default action.
    function open(notification: Notification) {
        const onOpen = opens[notification.id];
        if (onOpen) {
            onOpen();
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

    NotificationServer {
        id: server

        keepOnReload: false
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;
            notifications.unseen = true;
            if (!Settings.doNotDisturb || notification.urgency === NotificationUrgency.Critical)
                notifications.banners = [notification, ...notifications.banners];
            notification.closed.connect(() => {
                notifications.hideBanner(notification);
                const changed = Object.assign({}, notifications.opens);
                delete changed[notification.id];
                notifications.opens = changed;
            });
        }
    }

    // One post: gdbus answers with the notification's id, "(uint32 7,)".
    Component {
        id: poster

        Process {
            id: post

            property var onOpen

            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    const id = /uint32 (\d+)/.exec(text)?.[1];
                    if (id)
                        notifications.opens = Object.assign({}, notifications.opens, { [id]: post.onOpen });
                }
            }
            onRunningChanged: {
                if (!running)
                    destroy();
            }
        }
    }
}
