// The notifications' rules as data, for Notifications.qml, and the unit test
// tests/unit/shell/tst_notifications.qml. `apps` is what the person chose for
// each application that has sent a notification: { key: { name, mode } }.
// Each function returns new values and changes none it is given.
.pragma library

// What an application's notifications do: show as banners and stay in the
// center, only stay in the center, or are dropped.
var modes = ["Banners", "Center only", "Off"];

// How long Do Not Disturb stays on.
var quietChoices = ["For 1 hour", "Until tomorrow", "Until turned off"];

// The banners shown at once; the rest are counted.
var maxBanners = 3;

// The urgencies, as the notification specification numbers them.
var low = 0;
var critical = 2;

// When "Until tomorrow" ends: this hour of the morning.
var morning = 7;

// The application a notification is from: its desktop entry, or its name.
function keyOf(notification) {
    return notification.desktopEntry || notification.appName || "";
}

function modeOf(apps, key) {
    var mode = apps[key] ? apps[key].mode : "";
    return modes.indexOf(mode) >= 0 ? mode : modes[0];
}

// Whether the application's notifications are kept at all.
function keeps(apps, key) {
    return modeOf(apps, key) !== "Off";
}

// Whether a notification shows as a banner. Low ones never do; while it is
// quiet (Do Not Disturb, or the screen is shared), only critical ones do.
function banners(apps, key, urgency, quiet) {
    if (modeOf(apps, key) !== "Banners" || urgency === low)
        return false;
    return !quiet || urgency === critical;
}

// Whether only the quiet holds a notification's banner back.
function held(apps, key, urgency, quiet) {
    return quiet && !banners(apps, key, urgency, true) && banners(apps, key, urgency, false);
}

// The applications with one more, by its name; null when it is there already.
function remember(apps, key, name) {
    if (!key || (apps[key] && apps[key].name === (name || key)))
        return null;
    var next = JSON.parse(JSON.stringify(apps));
    next[key] = { name: name || key, mode: modeOf(apps, key) };
    return next;
}

// Sets what an application's notifications do; `name` names one that has
// sent none yet.
function setMode(apps, key, mode, name) {
    var next = JSON.parse(JSON.stringify(apps));
    next[key] = { name: apps[key] ? apps[key].name : name || key, mode: mode };
    return next;
}

// The applications as a list, by name: [{ key, name, mode }].
function list(apps) {
    return Object.keys(apps).map(function (key) {
        return { key: key, name: apps[key].name || key, mode: modeOf(apps, key) };
    }).sort(function (a, b) { return a.name.localeCompare(b.name); });
}

// Notifications, newest first, grouped by application: [{ key, name, items }],
// the group with the newest notification first, each group's newest first.
function groups(notifications) {
    var out = [];
    var byKey = {};
    notifications.forEach(function (notification) {
        var key = keyOf(notification);
        if (!byKey[key]) {
            byKey[key] = { key: key, name: notification.appName || key, items: [] };
            out.push(byKey[key]);
        }
        byKey[key].items.push(notification);
    });
    return out;
}

// When Do Not Disturb ends by itself, in milliseconds since the epoch, for a
// choice made at `now`; 0 for never. Tomorrow is the next morning that is at
// least an hour away.
function quietUntil(choice, now) {
    if (choice === "For 1 hour")
        return now + 3600000;
    if (choice !== "Until tomorrow")
        return 0;
    var end = new Date(now);
    end.setHours(morning, 0, 0, 0);
    while (end.getTime() - now < 3600000)
        end.setDate(end.getDate() + 1);
    return end.getTime();
}

function quietOver(until, now) {
    return until > 0 && now >= until;
}

// Where the banners show, nearest the notifications' item, by the edge of
// its bar and its zone there: { top, side }, at the top or the bottom of the
// screen, on its "left", its "right", or in its "center". Off the bars, the
// top right.
function corner(edge, zone) {
    var across = zone === "start" ? "left" : zone === "center" ? "center" : "right";
    switch (edge) {
    case "Top":
        return { top: true, side: across };
    case "Bottom":
        return { top: false, side: across };
    case "Left":
        return { top: zone !== "end", side: "left" };
    case "Right":
        return { top: zone !== "end", side: "right" };
    default:
        return { top: true, side: "right" };
    }
}
