// The assistant's modes and keys as data, for Assistant.qml, and the unit test
// tests/unit/shell/tst_assistant.qml. One conversation shows in one of three
// ways: bubbles by the assistant's button, a panel over the windows at the
// right of the screen, or that panel docked beside the windows. Each function
// returns new values and changes none it is given.
.pragma library

// How long Super is held alone, in milliseconds, before it listens; let go
// sooner, it is a tap.
var holdAfter = 400;
// How long it listens at most, in milliseconds: a key whose letting go never
// comes, as when something else takes the keyboard, must not leave the
// microphone open.
var longestHold = 60000;
// How many of the latest bubbles show in full; the ones before are dimmed.
var fullBubbles = 3;
// How long after a click outside closed the panel a tap does not open it
// again, in milliseconds: the click was on the hot corner's assistant button.
var dismissFor = 500;
// How long bubbles that came up by themselves stay, in milliseconds.
var peekFor = 6000;
// Below this width, in pixels, a screen has no room for a docked panel.
var narrowBelow = 1024;
// The docked panel's width, in pixels: the least, the most as a share of the
// screen, and what it is until changed.
var leastWidth = 280;
var mostShare = 0.5;
var defaultWidth = 340;

// A view: { open, docked, focused, last }. `open` is "" (hidden), "bubbles",
// or "panel"; `docked` says the panel sits beside the windows, not over them;
// `focused` that the docked panel has the keyboard; `last` is the way the
// assistant was last opened, "bubbles" or "panel".
function view(open, docked, focused, last) {
    return { open: open, docked: docked, focused: focused, last: last };
}

// A tap on Super, or a click on the assistant's button: opens what was open
// last, or closes what is open, docked or not.
function tap(now) {
    if (now.open === "")
        return view(now.last === "panel" ? "panel" : "bubbles", now.docked, true, now.last);
    return view("", now.docked, false, now.last);
}

// A bubble's "open in panel", or the right edge of the screen.
function toPanel(now) {
    return view("panel", now.docked, true, "panel");
}

// The panel's dock button; a narrow screen keeps the panel over the windows.
function dock(now, docked, narrow) {
    return view(now.open, docked && !narrow, now.focused, now.last);
}

// Escape, or a click outside the panel over the windows.
function hide(now) {
    return view("", now.docked, false, now.open === "" ? now.last : now.open);
}

// Whether the panel reserves its width, so that windows retile beside it.
function reserves(now, narrow) {
    return now.open === "panel" && now.docked && !narrow;
}

// The Super key. `state` is "idle", "pressed" (down alone, not yet held), or
// "listening". `event` is "down" (Super pressed with no other key down),
// "other" (any other key or button while Super is down), "held" (holdAfter
// has passed), "long" (longestHold has passed), or "up". Returns { state, action }, the action one of "",
// "tap", "listen", "send" (the speech is the request), or "cancel" (the
// speech is discarded: the key began a shortcut).
function key(state, event) {
    if (event === "down")
        return { state: state === "idle" ? "pressed" : state, action: "" };
    if (state === "pressed") {
        if (event === "up")
            return { state: "idle", action: "tap" };
        if (event === "held")
            return { state: "listening", action: "listen" };
        return { state: "idle", action: "" };
    }
    if (state === "listening") {
        if (event === "up")
            return { state: "idle", action: "send" };
        if (event === "other" || event === "long")
            return { state: "idle", action: "cancel" };
    }
    return { state: state, action: "" };
}

// Whether a conversation last used at `updated` goes on at `now`, both in
// seconds: left for longer than restAfter, the next request begins a new one.
var restAfter = 1800;
function continues(updated, now) {
    return now - updated < restAfter;
}

// Whether the bubble at `index` of `count`, the oldest first, is dimmed. They
// all show in full once the person scrolls back through them.
function dimmed(index, count, scrolled) {
    return !scrolled && index < count - fullBubbles;
}

// Whether a message that came or changed brings the bubbles up by themselves:
// with the assistant hidden and no other panel open, an answer that ended, or
// an action that waits for the person. `message` is as Assistant.messages
// holds them.
function peeks(now, panelOpen, message) {
    if (now.open !== "" || panelOpen)
        return false;
    if (message.role === "action")
        return ["proposed", "done", "failed"].indexOf(message.state) >= 0;
    if (message.role === "assistant")
        return message.state === "failed" || (message.state === "done" && !!message.text);
    return false;
}

// Whether bubbles that came up by themselves go again: not while one waits
// for the person, or the pointer is on them.
function peekEnds(attention, hovered) {
    return !attention && !hovered;
}

// The docked panel's width, kept between the least and the screen's share.
function width(wanted, screenWidth) {
    return Math.round(Math.max(leastWidth, Math.min(screenWidth * mostShare, wanted)));
}

// Why the assistant cannot listen now, or "": `locked` the screen, `asking`
// a password prompt, `dictating` dictation under way, `engine` the speech
// model is on the computer, `microphone` there is one, `ready` the
// assistant's model is on the computer.
function cannotListen(locked, asking, dictating, engine, microphone, ready) {
    if (locked || asking)
        return "locked";
    if (dictating)
        return "dictating";
    if (!ready || !engine)
        return "download";
    if (!microphone)
        return "microphone";
    return "";
}

// What a request tells the model of where the person is: the selected text,
// cut to `limit` characters, and the focused window's application and title.
// Nothing else of the screen goes along.
function context(selection, app, title, limit) {
    var said = {};
    var text = (selection || "").trim();
    if (text)
        said.selection = text.slice(0, limit);
    if (app)
        said.app = app;
    if (title)
        said.title = title.slice(0, 200);
    return said;
}
