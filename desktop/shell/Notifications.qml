// The notification server: applications' notifications, kept until they are
// dismissed (NotificationsPanel.qml), and shown as banners while new
// (NotificationBanners.qml). Do Not Disturb (Settings) holds banners back,
// except critical ones; the notifications are kept all the same.
pragma Singleton
import QtQuick
import Quickshell
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

    function hideBanner(notification: Notification) {
        banners = banners.filter(n => n !== notification);
    }

    // Opens what the notification is about, through its default action.
    function open(notification: Notification) {
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
            notification.closed.connect(() => notifications.hideBanner(notification));
        }
    }
}
