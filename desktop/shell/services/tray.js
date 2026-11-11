// The background apps' icons as data, for Tray.qml, TrayIcons.qml, and
// TrayMenu.qml, and the unit test tests/unit/shell/tst_tray.qml.
.pragma library

// The share of an icon's place that shows of each stacked icon but the last.
var stackedShare = 0.5;

// The icons to show: those whose application has not set them passive,
// which asks for them to be out of sight.
function shown(items, passive) {
    return items.filter(function (item) { return item.status !== passive; });
}

// How far each icon stands from the one before it along the bar: its place
// and the spacing side by side, or a part of its place while stacked.
function pitch(place, spacing, stacked, open) {
    return stacked && !open ? Math.round(place * stackedShare) : place + spacing;
}

// How long `count` icons are along the bar, `pitch` apart.
function length(count, place, pitch) {
    return count > 0 ? place + (count - 1) * pitch : 0;
}

// The name of an icon given by name in the icon theme, from its source as
// Quickshell gives it, "image://icon/<name>"; empty for one the application
// draws itself, or keeps in a folder of its own ("?path=").
function iconName(source) {
    var prefix = "image://icon/";
    return source.indexOf(prefix) === 0 && source.indexOf("?") < 0 ? source.slice(prefix.length) : "";
}

// Whether an icon is a symbolic one, drawn in one color for the shell to
// give its own.
function symbolic(source) {
    return /-symbolic(\?|$)/.test(source);
}

// A menu entry's label without the marks of its access key: "_Quit" reads
// "Quit", and "__" is an underscore.
function label(text) {
    return text.replace(/_(_?)/g, "$1");
}
