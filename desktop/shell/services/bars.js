// The bars' layout as data, for Shell.qml and Settings.qml, and the unit test
// tests/unit/shell/tst_bars.qml. `zones` is { bar: { start, center, end } }
// with lists of item ids in order, `hidden` the ids on neither bar. Each
// function returns new values and changes none it is given.
.pragma library

var zoneNames = ["start", "center", "end"];

// Items that keep their size: the rest are buttons, which can be half size.
var whole = ["clock", "workspaces", "tray"];

// The quick actions were one item, "quick", until each became one of its own.
var quick = ["capture", "dictation", "assistant"];

function copy(value) {
    return JSON.parse(JSON.stringify(value));
}

function canHalve(item) {
    return whole.indexOf(item) < 0;
}

// Where an item is: { bar, zone, index }, with bar and zone "" when hidden;
// null when on neither the bars nor the hidden list.
function find(zones, hidden, item) {
    for (var bar in zones)
        for (var zone in zones[bar]) {
            var index = zones[bar][zone].indexOf(item);
            if (index >= 0)
                return { bar: bar, zone: zone, index: index };
        }
    var at = hidden.indexOf(item);
    return at >= 0 ? { bar: "", zone: "", index: at } : null;
}

// Moves an item to a bar's zone at an index of that list as it is shown,
// with the item still where it was; an index past the end, or below 0, puts
// it last. With no bar, the item goes to the hidden list.
function move(zones, hidden, item, bar, zone, index) {
    var from = find(zones, hidden, item);
    var next = copy(zones);
    for (var b in next)
        for (var z in next[b])
            next[b][z] = next[b][z].filter(function (i) { return i !== item; });
    var rest = hidden.filter(function (i) { return i !== item; });
    var list = bar ? next[bar][zone] : rest;
    var at = index < 0 ? list.length : index;
    if (from && from.bar === (bar || "") && from.zone === (bar ? zone : "") && from.index < at)
        at -= 1;
    list.splice(Math.min(at, list.length), 0, item);
    return { zones: next, hidden: rest };
}

// Moves an item one place toward the start (-1) or the end (1) of its bar:
// within its zone, or past the zone's edge into the next zone of the bar.
// Null when it is at the bar's end already, or hidden.
function step(zones, hidden, item, delta) {
    var from = find(zones, hidden, item);
    if (!from || !from.bar)
        return null;
    var list = zones[from.bar][from.zone];
    var index = from.index + delta;
    if (index >= 0 && index < list.length)
        return move(zones, hidden, item, from.bar, from.zone, delta > 0 ? index + 1 : index);
    var zone = zoneNames[zoneNames.indexOf(from.zone) + delta];
    if (!zone)
        return null;
    return move(zones, hidden, item, from.bar, zone, delta > 0 ? 0 : -1);
}

// Where an item goes back to when shown again: its zone by default, or the
// end of the dock.
function home(defaults, item) {
    var at = find(defaults, [], item);
    return at || { bar: "dock", zone: "end", index: -1 };
}

// A zone's items in slots across the bar: half-size items stand two to a
// slot, each beside the half-size one before it.
function slots(ids, half) {
    var out = [];
    ids.forEach(function (id) {
        var last = out[out.length - 1];
        var small = half.indexOf(id) >= 0 && canHalve(id);
        if (small && last && last.length === 1 && half.indexOf(last[0]) >= 0 && canHalve(last[0]))
            last.push(id);
        else
            out.push([id]);
    });
    return out;
}

// Brings saved settings up to date: the old "quick" item becomes its three
// buttons in its place, without the dictation button if that was off; items
// that are no more, such as the downloads, now in the notifications' panel,
// go; then zones the saved ones lack, such as all of them before the first save, are
// made, and items they lack, such as ones added since, go where they are by
// default, before the next item that follows them there. Returns { zones,
// hidden, changed }.
function migrate(zones, hidden, defaults, dictationShown) {
    var next = copy(zones);
    var rest = hidden.slice();
    var changed = false;
    var lists = [rest];
    for (var b in next)
        for (var z in next[b])
            lists.push(next[b][z]);
    lists.forEach(function (list) {
        var at = list.indexOf("quick");
        if (at < 0)
            return;
        var shown = quick.filter(function (i) { return dictationShown || i !== "dictation"; });
        list.splice.apply(list, [at, 1].concat(shown));
        if (!dictationShown && rest.indexOf("dictation") < 0)
            rest.push("dictation");
        changed = true;
    });

    var known = {};
    for (var kb in defaults)
        for (var kz in defaults[kb])
            defaults[kb][kz].forEach(function (id) { known[id] = true; });
    lists.forEach(function (list) {
        for (var i = list.length - 1; i >= 0; i--)
            if (!known[list[i]]) {
                list.splice(i, 1);
                changed = true;
            }
    });

    var placed = {};
    rest.forEach(function (id) { placed[id] = true; });
    for (var bar in next)
        for (var zone in next[bar])
            next[bar][zone].forEach(function (id) { placed[id] = true; });
    for (var db in defaults)
        for (var dz in defaults[db]) {
            if (!next[db])
                next[db] = {};
            if (!next[db][dz]) {
                next[db][dz] = [];
                changed = true;
            }
            var ids = defaults[db][dz];
            ids.forEach(function (id, index) {
                if (placed[id])
                    return;
                var list = next[db][dz];
                var following = ids.slice(index + 1).filter(function (other) {
                    return list.indexOf(other) >= 0;
                })[0];
                list.splice(following ? list.indexOf(following) : list.length, 0, id);
                placed[id] = true;
                changed = true;
            });
        }
    return { zones: next, hidden: rest, changed: changed };
}
