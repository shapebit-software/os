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

// How long after a tap, in milliseconds, a second one makes a double tap.
var doubleTapWithin = 350;

// The Super key. `state` is "idle", "pressed" (down alone, not yet held),
// "listening", "tapped" (a tap just ended, and a second may come), or
// "pressed again" (down for that second tap). `event` is "down" (Super pressed
// with no other key down), "other" (any other key or button while Super is
// down), "held" (holdAfter has passed), "long" (longestHold has passed), "up",
// or "late" (doubleTapWithin has passed since a tap). Returns { state, action },
// the action one of "", "tap", "listen", "send" (the speech is the request),
// "cancel" (the speech is discarded: the key began a shortcut), or "converse"
// (a double tap: voice mode). The first tap of a double tap acts as a tap, so
// a single one never waits.
function key(state, event) {
    if (state === "tapped") {
        if (event === "down")
            return { state: "pressed again", action: "" };
        return { state: "idle", action: "" };
    }
    if (event === "down")
        return { state: state === "idle" ? "pressed" : state, action: "" };
    if (state === "pressed" || state === "pressed again") {
        if (event === "up")
            return state === "pressed" ? { state: "tapped", action: "tap" } : { state: "idle", action: "converse" };
        if (event === "held")
            return { state: "listening", action: "listen" };
        if (event === "late")
            return { state: state, action: "" };
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

// What marks an answer as Markdown: a heading, a list, bold, code, a quote,
// a link, or a table. An answer without any shows as plain text.
var markdownMarks = [
    /^#{1,6}\s+\S/m,
    /^\s*[-*+]\s+\S/m,
    /^\s*\d+[.)]\s+\S/m,
    /\*\*[^*\n]+\*\*/,
    /__[^_\n]+__/,
    /`[^`\n]+`/,
    /^\s*```/m,
    /^>\s?\S/m,
    /\[[^\]\n]+\]\([^)\s]+\)/,
    /^\s*\|.*\|\s*$/m,
];

// An answer as Markdown, for Text.MarkdownText, or "" when it reads as plain
// text. An answer may carry text from web pages or windows, which must not
// make the shell fetch anything: outside code, HTML shows as text, and a
// picture becomes a link, to open only if clicked. A link to a web page or
// mail address is written as HTML of our own, in `linkColor`, which Qt's
// Markdown would not take; any other link is its label alone. Code stays as
// written; an answer still coming may leave its last block open.
function markdown(text, linkColor) {
    if (!text || !markdownMarks.some(function (mark) { return mark.test(text); }))
        return "";
    var parts = text.split(/(^\s*```[\s\S]*?(?:^\s*```[^\n]*$|(?![\s\S]))|`[^`\n]+`)/m);
    return parts.map(function (part, index) {
        if (index % 2 === 1)
            return part;
        return part.replace(/</g, "&lt;").replace(/!\[/g, "[").replace(/\[([^\]\n]*)\]\(([^)\s]*)\)/g, function (all, label, url) {
            if (!opens(url) || /["']/.test(url))
                return label;
            return '<a href="' + url + '"><font color="' + (linkColor || "") + '">' + (label || url) + "</font></a>";
        });
    }).join("");
}

// Whether a link in an answer may open, in the person's browser.
function opens(link) {
    return /^(https?|mailto):/i.test(link || "");
}

// What was said in voice mode, as words only: no case, and no punctuation at
// either end, which the speech engine adds.
function plainly(said) {
    return (said || "").toLowerCase().replace(/’/g, "'").replace(/[.,!?;:…"“”„]+/g, " ").replace(/\s+/g, " ").trim();
}

// What a short answer said in voice mode means for an action that waits:
// "apply", "decline", or "" when it is no answer but a request. Only the whole
// of what was said counts, with a "please" at most.
var yesWords = ["yes", "yeah", "yep", "ok", "okay", "sure", "do it", "go ahead", "apply", "confirm",
                "tak", "dobrze", "zgoda", "jasne", "zrób to", "potwierdzam"];
var noWords = ["no", "nope", "cancel", "don't", "dont", "do not", "never mind",
               "nie", "anuluj", "nie rób tego", "nieważne"];
function spokenAnswer(said) {
    var words = plainly(said).replace(/^(please|proszę) | (please|proszę)$/g, "");
    if (yesWords.indexOf(words) >= 0)
        return "apply";
    if (noWords.indexOf(words) >= 0)
        return "decline";
    return "";
}

// Whether what was said in voice mode ends it.
// Where the whole sentences end in an answer being written, from `from` on: after
// the last ".", "!", "?", "…", ":" or ";" that a space follows, or a line's end;
// `from` with none. Voice mode says an answer sentence by sentence as it comes.
function sentencesEnd(text, from) {
    var end = from;
    var pattern = /[.!?…:;]["')\]]*\s|\n/g;
    pattern.lastIndex = from;
    var found;
    while ((found = pattern.exec(text)) !== null)
        end = found.index + found[0].length;
    return end;
}

var stopWords = ["stop", "stop listening", "that's all", "thats all", "that is all", "goodbye",
                 "koniec", "wystarczy", "przestań słuchać", "stop słuchania", "dziękuję to wszystko"];
function stopsListening(said) {
    return stopWords.indexOf(plainly(said)) >= 0;
}
