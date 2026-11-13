// The assistant, as the shell shows it: one conversation, in one of three
// ways (assistant.js): as bubbles by the assistant's button
// (bar/AssistantBubbles.qml), the latest few in full; in a panel at the right
// of the screen, over the windows (bar/AssistantDock.qml); or in that panel
// docked, which reserves its width, so the windows retile beside it. The
// panel also lists all the conversations, with a search. A tap on Super, or
// a click on the button, opens what was open last; held, either listens
// until let go, and what was said is the request: the button shows the
// listening and the thinking, and the answer comes up as a bubble.
// A request tells the model the selected text and the focused window's
// application and title, as the reply line shows; more of the screen only
// through the actions of the "screen" group, which ask on their card until
// the person allows the group.
// assistant/assistant does the work in a user service of its own, so hiding
// the shell, or restarting it, stops nothing; this talks to it over its
// socket, shows what it says, and does the actions that are the shell's,
// such as Do Not Disturb, when it asks (the IpcHandler below). Its model is
// an extra (Extras.qml) until another one is chosen.
pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import "assistant.js" as Logic

Singleton {
    id: assistant

    // Its icon: a face, a rounded square with two eyes, as one outline; the
    // eyes are rings drawn so thick that they show as dots. The button on the
    // bars draws it itself, to move the eyes (bar/QuickButton.qml).
    readonly property string face: "M5.5 2.5h5a3 3 0 0 1 3 3v5a3 3 0 0 1-3 3h-5a3 3 0 0 1-3-3v-5a3 3 0 0 1 3-3z"
    readonly property string icon: face + "M5.6 7.5a.6 .6 0 1 0 1.2 0a.6 .6 0 1 0-1.2 0zM9.2 7.5a.6 .6 0 1 0 1.2 0a.6 .6 0 1 0-1.2 0z"

    // In development (make run), the shell starts the assistant itself, on a
    // socket of its own; otherwise systemd starts it on the first connection.
    readonly property string tree: Quickshell.env("DESKTOP_SHELL")
    readonly property string path: `${Quickshell.env("XDG_RUNTIME_DIR")}/assistant${tree ? "-" + Quickshell.env("WAYLAND_DISPLAY") : ""}.sock`
    readonly property bool connected: (socket?.connected ?? false) && greeted
    property bool greeted

    // Each: { id, title, workspace, updated, snippet }, the latest first.
    property var conversations: []
    // The one open, { id, title, workspace, messages }, or null for a new one.
    property var conversation: null
    readonly property var messages: conversation?.messages ?? []
    // "idle", "thinking", "starting", "answering", or "waiting" (a card).
    property string status: "idle"
    property bool busy
    property int queued
    // An action waits for the person.
    property bool attention
    // { id, name, mark, color, where, extra, ready, sees, provider, model,
    // own }, or null.
    property var model: null
    property var models: []
    // The groups allowed, and every group's description, by id.
    property list<string> grants
    property var groups: ({})
    // Days the activity log keeps; 0 is for ever.
    property int retention: 30
    // "ready": the local model loads a little after sign-in and stays;
    // "used": it loads with a request, and goes after ten minutes unused.
    property string loading: "ready"
    // The skills, { name, description, temperature, instructions, own }, and
    // the actions, { name, description, risk, group }, as the model has them.
    property var skills: []
    property var tools: []
    // The answer to the last skill saved or deleted: "" or why it failed.
    property string skillError
    signal skillSaved(name: string)
    // The online providers, by id: { name, auth: "plan" or "key", usage: its
    // page of usage }; the ChatGPT account signed in, { email }, or null; and
    // what Settings > Assistant > Models is doing: the models a provider
    // listed, by provider, each { models } or { error }; a sign-in under way;
    // and the last error of adding a model.
    property var providers: ({})
    property var chatgpt: null
    property var providerModels: ({})
    property bool signingIn
    property string signInError
    property string addError
    signal modelAdded(id: string)
    // The conversation deleted last, { id, title }, for Undo.
    property var deleted: null
    // The search's ids, or null with no search.
    property var found: null
    property string query

    // The screen the panel is open on, by name, or "".
    property string panelOn
    // Whether the docked panel has the keyboard, and whether the panel lists
    // the conversations rather than showing one.
    property bool panelFocused
    property bool listing
    // An answer, or an action, that came while the assistant was hidden: it
    // shows in the pill by the button (VoicePill.qml), as voice mode's answers
    // do, and goes again by itself, unless it waits for the person or the
    // pointer is on it; a click on it opens the bubbles.
    property var note: null
    property bool peekHovered
    // What is open, as assistant.js holds it.
    readonly property var view: Logic.view(panelOn !== "" ? "panel" : Shell.panel === "assistant" ? "bubbles" : "",
        Settings.assistantDocked, panelFocused, Settings.assistantLast)

    // The Super key, "idle", "pressed", or "listening" (assistant.js), and
    // the voice: "" , "listening", or "writing", with the microphone's
    // level, 0 to 1, and a word for the button when it cannot listen or
    // heard nothing.
    property string keyState: "idle"
    property string voice
    // Voice mode, apart from the conversations: it hears on, and each pause
    // makes what was said a request (dictation/hear --converse), in a
    // conversation of its own that the service keeps in memory only and
    // forgets at the end. Its pill shows by the assistant's button
    // (VoicePill.qml), as notes do: at pillAt, { screen, rect, edge, depth }
    // as the bar tells it, or with no rect in a corner of the screen. With what voice
    // mode said and did; what is being said only tells that the person speaks.
    property bool conversing
    // The words said so far, phrase by phrase, until they are a request; and
    // whether a phrase has begun since (dictation/hear), so the button shows
    // that the person speaks before any word is written down.
    property string draft
    property bool speech
    property var pillAt: null
    property string voiceConversation
    property var voiceMessages: []
    // A request just said, until its message comes back; and a word for the
    // person when what they said did nothing, such as yes to what needs a click.
    property bool voiceSent
    property string voiceNotice
    readonly property var voiceWaiting: voiceMessages.find(m => m.role === "action" && m.state === "proposed") ?? null
    readonly property var voiceLast: voiceMessages.length ? voiceMessages[voiceMessages.length - 1] : null
    // Voice mode says its answers aloud (dictation/speak), with Settings >
    // Assistant's "Speak answers" and the voices downloaded; while it does,
    // it does not hear, so that it never takes its own voice for a request.
    readonly property bool canTalk: Settings.assistantSpeaks && Extras.list.some(e => e.id === "voices" && e.installed)
    property bool talking
    // How much of each answer has gone to be said, by its message's id.
    property var toldUpTo: ({})
    // Voice mode's state, for its button and pill: "talking" (it says its
    // answer), "speaking" (words being said), "waiting" (an action waits for
    // the person), "thinking" (a request under way), "listening", or "" with
    // voice mode off.
    readonly property string voiceState: !conversing ? ""
        : talking ? "talking"
        : speech || draft !== "" ? "speaking"
        : voiceWaiting ? "waiting"
        : voiceSent || voiceLast && (voiceLast.role === "user" || voiceLast.state === "running"
            || ["thinking", "starting", "answering"].includes(voiceLast.state)) ? "thinking"
        : "listening"
    // Asks the assistant's button on a screen where it is, for the pill.
    signal pillAsked(screen: string)
    // Dictated text tidied up by the model (dictation's Tidy up, Dictation.qml):
    // { id, text, done } as it is written, or { id, error }.
    signal tidied(event: var)

    function tidy(id: string, text: string) {
        if (socket?.connected)
            request({ op: "tidy", id, text });
        else
            tidied({ id, error: "The assistant isn't running." });
    }
    property real level
    property string notice
    // What the next request tells of where the person is, { selection, app,
    // title }, each only if there; the reply line shows it, to take off.
    property var context: ({})

    readonly property bool answering: busy || messages.some(m => m.state === "proposed")
    // The model's extra, and how its download goes (Extras.qml).
    readonly property var extra: Extras.list.find(e => e.id === model?.extra) ?? null
    readonly property var download: extra ? Extras.progress[extra.id] ?? null : null
    readonly property bool ready: model?.ready ?? false
    // That an AI answers, wherever the assistant is used: people must know (the EU's
    // AI Act, article 50).
    readonly property string disclosure: model?.where === "online"
        ? `Answers come from ${providers[model?.provider]?.name ?? "an online AI model"}, online, and can be wrong.`
        : "Answers come from an AI model on this computer, and can be wrong."

    function request(fields: var) {
        if (!socket?.connected)
            return;
        if (fields.op === "send" || fields.op === "warm")
            modelWanted = true;
        socket.write(JSON.stringify(fields) + "\n");
        socket.flush();
    }

    // A new request: in the open conversation, or a new one, with what the
    // reply line shows of where the person is.
    function send(text: string) {
        text = text.trim();
        if (!text)
            return;
        request({ op: "send", id: current(), text, context });
        context = ({});
    }

    // The conversation a request goes on in, or null for a new one: in the
    // panel, the one it shows; otherwise the one open, unless it was left
    // for a while.
    function current(): var {
        if (!conversation)
            return null;
        const updated = conversations.find(c => c.id === conversation.id)?.updated ?? 0;
        if (view.open !== "panel" && !Logic.continues(updated, Date.now() / 1000)) {
            conversation = null;
            return null;
        }
        return conversation.id;
    }

    // Opening and closing ------------------------------------------------

    // Shows a view on a screen; `show` opens the bubbles, by default as the
    // assistant's button would.
    function apply(next: var, screen: string, show: var) {
        Settings.assistantDocked = next.docked;
        Settings.assistantLast = next.last;
        panelFocused = next.open === "panel" && next.focused;
        note = null;
        if (next.open === "panel") {
            if (Shell.panel === "assistant")
                Shell.close();
            panelOn = screen;
            return;
        }
        panelOn = "";
        listing = false;
        if (next.open === "bubbles") {
            Settings.assistantLast = "bubbles";
            if (!Shell.isOpen("assistant", screen)) {
                if (show)
                    show();
                else
                    Shell.request("assistant", screen);
            }
        } else if (Shell.panel === "assistant") {
            Shell.close();
        }
    }

    // A tap on Super, or a click on the assistant's button. The click that
    // closed the panel, on the hot corner's button outside it, is no tap of
    // its own.
    function tap(screen: string, show: var) {
        if (Lock.locked || view.open === "" && Date.now() - dismissedAt < Logic.dismissFor)
            return;
        const next = Logic.tap(view);
        if (next.open !== "" && view.open === "")
            look();
        apply(next, panelOn || screen, show);
    }

    // From a bubble, or the right edge of the screen.
    function openPanel(screen: string) {
        if (Lock.locked)
            return;
        apply(Logic.toPanel(view), screen, null);
    }

    // The panel, as bubbles again.
    function openBubbles(screen: string) {
        apply(Logic.view("bubbles", view.docked, false, "bubbles"), screen, null);
    }

    function dock(docked: bool, narrow: bool) {
        apply(Logic.dock(view, docked, narrow), panelOn, null);
    }

    function hide() {
        apply(Logic.hide(view), panelOn, null);
    }

    // A click outside the panel over the windows and the bars.
    property real dismissedAt
    function dismiss() {
        dismissedAt = Date.now();
        hide();
    }

    // A click on a bar off its items: closes the panel over the windows, not
    // the docked one.
    function clickedOff() {
        const screen = Quickshell.screens.find(s => s.name === panelOn);
        if (view.open === "panel" && !Logic.reserves(view, (screen?.width ?? 0) < Logic.narrowBelow))
            hide();
    }

    // An answer that came while hidden shows in the pill, by the button on
    // the screen the person is on, and goes again.
    function peek(message: var) {
        const screen = Shortcuts.focused;
        if (!screen || conversing)
            return;
        if (!note) {
            pillAt = null;
            pillAsked(screen);
            if (!pillAt)
                pillAt = { screen, rect: null };
        }
        note = message;
        peekTimer.restart();
    }

    // A click on the note: the bubbles, with the whole conversation.
    function openNote() {
        const screen = pillAt?.screen ?? Shortcuts.focused;
        note = null;
        pillAt = null;
        Settings.assistantLast = "bubbles";
        tap(screen, null);
    }

    function dropNote() {
        note = null;
        if (!conversing)
            pillAt = null;
    }

    // Where the person is: the selected text, and the focused window.
    function look() {
        selection.then = null;
        selection.running = true;
    }

    function drop(name: string) {
        const next = Object.assign({}, context);
        delete next[name];
        context = next;
    }

    // The voice ----------------------------------------------------------

    function helper(): string {
        return tree ? `${tree}/../dictation/hear` : "/usr/libexec/desktop/hear";
    }

    // Super, or the assistant's button, as assistant.js names what happens.
    function key(event: string) {
        // The list of shortcuts shows Super's while it is held.
        if (Shortcuts.listOn && keyState === "idle")
            return;
        const next = Logic.key(keyState, event);
        keyState = next.state;
        if (keyState === "pressed")
            hold.restart();
        else
            hold.stop();
        if (keyState === "listening")
            longest.restart();
        else
            longest.stop();
        if (keyState === "tapped")
            doubleTap.restart();
        if (next.action === "tap" && talking)
            silence();
        else if (next.action === "tap" && conversing)
            endConversation();
        else if (next.action === "tap")
            tap(Shortcuts.focused, null);
        else if (next.action === "converse")
            converse(Shortcuts.focused, null);
        else if (next.action === "listen")
            listen();
        else if (next.action === "send")
            endListening(true);
        else if (next.action === "cancel")
            endListening(false);
    }

    // Why voice can't be used now, as the button says it, or "".
    function cannotHear(): string {
        const why = Logic.cannotListen(Lock.locked, Authorization.asking, Dictation.active, Dictation.available,
            Audio.input !== null, ready);
        if (why === "" && Audio.input.audio?.muted)
            return "Microphone is muted";
        return why === "download" ? "Needs a download" : why === "microphone" ? "No microphone" : why === "" ? "" : " ";
    }

    // Voice mode, started by a double tap on Super or a right click on the
    // assistant's button, on `screen`; `at`, where the button is, if known.
    // Nothing opens but its pill. It hears until "stop", a tap on Super, a
    // right click again, or a minute without a sound.
    function converse(screen: string, at: var) {
        if (conversing || listener.running)
            return;
        notice = cannotHear().trim();
        if (cannotHear() !== "")
            return;
        note = null;
        pillAt = at;
        if (!pillAt)
            pillAsked(screen);
        if (!pillAt)
            pillAt = { screen, rect: null };
        request({ op: "warm" });
        level = 0;
        draft = "";
        speech = false;
        voiceConversation = "";
        voiceMessages = [];
        request({ op: "begin-voice" });
        voice = "listening";
        conversing = true;
        talking = false;
        toldUpTo = {};
        speaker.running = canTalk;
        // Otherwise it would answer only in writing, with no word why.
        if (Settings.assistantSpeaks && !canTalk)
            say("Answers are said aloud once Spoken answers is downloaded, in Settings > Assistant");
        listener.command = [helper(), "--converse"];
        listener.running = true;
    }

    function toggleConversation(screen: string, at: var) {
        if (talking)
            silence();
        else if (conversing)
            endConversation();
        else
            converse(screen, at);
    }

    // At once: what is still being said is dropped, as its answer would never
    // show, its conversation forgotten. The button and the pill show it ended
    // before the helper is gone.
    function endConversation() {
        if (!conversing)
            return;
        if (listener.running)
            listener.write(JSON.stringify({ do: "discard" }) + "\n");
        voiceOff();
    }

    // The answer so far, said sentence by sentence as it comes; the rest, and
    // its end, once it is done.
    function tell(message: var) {
        if (!speaker.running || message.role !== "assistant")
            return;
        const from = toldUpTo[message.id] ?? 0;
        if (from < 0)
            return;
        const text = message.text ?? "";
        const done = !["thinking", "starting", "answering"].includes(message.state);
        const upTo = done ? text.length : Logic.sentencesEnd(text, from);
        if (upTo > from)
            speaker.write(JSON.stringify({ say: text.slice(from, upTo) }) + "\n");
        if (done)
            speaker.write(JSON.stringify({ end: true }) + "\n");
        toldUpTo[message.id] = done ? -1 : upTo;
    }

    // Stops saying the answer, and hears again: voice mode goes on.
    function silence() {
        if (speaker.running)
            speaker.write(JSON.stringify({ do: "stop" }) + "\n");
    }

    function voiceOff() {
        if (voiceConversation)
            request({ op: "forget", id: voiceConversation });
        conversing = false;
        draft = "";
        speech = false;
        speaker.running = false;
        talking = false;
        voiceConversation = "";
        voiceMessages = [];
        pillAt = null;
        voiceSent = false;
        voiceNotice = "";
        if (voice === "listening")
            voice = "";
    }

    // What was said in voice mode: the end of it, an answer to the action
    // that waits, or a request. The service takes only "yes" to a change,
    // never to what asks every time.
    function spoken(text: string) {
        draft = "";
        speech = false;
        voiceNotice = "";
        if (!text.trim())
            return;
        if (Logic.stopsListening(text)) {
            endConversation();
            return;
        }
        const waiting = voiceWaiting;
        const choice = waiting ? Logic.spokenAnswer(text) : "";
        if (choice === "apply" && waiting.risk !== "change") {
            say(`${waiting.title} needs a click: yes can't be said to it`);
        } else if (choice) {
            gotIt();
            request({ op: "answer", card: waiting.id, choice, spoken: true });
        } else {
            if (waiting)
                say(`First “${waiting.title}”: yes or no`);
            gotIt();
            voiceSent = true;
            request({ op: "send", id: voiceConversation || null, text, context: ({}), spoken: true, ephemeral: true });
        }
    }

    // A soft sound the moment a spoken request is taken, with Settings >
    // Assistant's "Sound when it hears you", so the person knows it heard
    // before the answer comes: the sound theme's short "message", at half
    // its loudness.
    // In voice mode, it does not hear the sound, as it does not hear itself.
    function gotIt() {
        if (!Settings.assistantSounds)
            return;
        Quickshell.execDetached(["pw-play", "--volume", "0.5", "/usr/share/sounds/freedesktop/stereo/message.oga"]);
        if (conversing && listener.running && !talking) {
            listener.write(JSON.stringify({ do: "pause" }) + "\n");
            gotItEnds.restart();
        }
    }

    // A word in voice mode's pill, for a while.
    function say(text: string) {
        voiceNotice = text;
        voiceNoticeEnds.restart();
    }

    function listen() {
        // Voice mode already hears.
        if (listener.running)
            return;
        notice = "";
        const why = Logic.cannotListen(Lock.locked, Authorization.asking, Dictation.active, Dictation.available,
            Audio.input !== null, ready);
        if (why === "" && Audio.input.audio?.muted)
            notice = "Microphone is muted";
        else if (why === "download")
            notice = "Needs a download";
        else if (why === "microphone")
            notice = "No microphone";
        // The button says why not; nothing opens, as Super may only have
        // been held on the way to a shortcut.
        if (why !== "" || notice !== "")
            return;
        // The model loads while the person speaks.
        request({ op: "warm" });
        level = 0;
        voice = "listening";
        listener.command = [helper()];
        listener.running = true;
    }

    // Let go: what was said is the request; or the key began a shortcut, and
    // what was said is discarded.
    function endListening(keep: bool) {
        // Voice mode goes on: Super held and let go there is not its end.
        if (!listener.running || conversing && keep)
            return;
        listener.write(JSON.stringify({ do: keep && voice === "listening" ? "stop" : "discard" }) + "\n");
        if (!keep)
            voice = "";
    }

    function heard(line: string) {
        let message;
        try {
            message = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (message.state === "listening") {
            level = message.level ?? 0;
        } else if (message.state === "speaking" && conversing) {
            speech = true;
        } else if (message.state === "draft" && conversing) {
            speech = false;
            draft = message.text ?? "";
        } else if (message.state === "heard") {
            spoken(message.text ?? "");
        } else if (conversing && message.state === "done") {
            spoken(message.text ?? "");
        } else if (conversing && message.state === "nothing") {
            draft = "";
        } else if (message.state === "writing") {
            voice = "writing";
        } else if (message.state === "nothing") {
            notice = "Didn't catch that";
        } else if (message.state === "failed") {
            notice = "Couldn't hear that";
        } else if (message.state === "done" && voice !== "") {
            // With the selection and the window as they are now.
            selection.then = message.text;
            selection.running = true;
        }
    }

    // What was said, as a request.
    function sendSpoken(text: string) {
        gotIt();
        request({ op: "send", id: current(), text, context, spoken: true });
        context = ({});
    }

    function stop() {
        request({ op: "stop" });
    }

    // choice: "apply", "always", or "decline".
    function answer(card: string, choice: string) {
        request({ op: "answer", card, choice });
    }

    function undo(card: string) {
        request({ op: "undo", card });
    }

    function open(id: string) {
        request({ op: "open", id });
    }

    function startNew() {
        conversation = null;
        listing = false;
    }

    function rename(id: string, title: string) {
        request({ op: "rename", id, title });
    }

    function remove(id: string) {
        if (conversation?.id === id)
            conversation = null;
        request({ op: "delete", id });
    }

    function restore() {
        if (deleted)
            request({ op: "restore", id: deleted.id });
        deleted = null;
    }

    function search(text: string) {
        query = text;
        if (text.trim())
            request({ op: "search", query: text });
        else
            found = null;
    }

    function chooseModel(id: string) {
        request({ op: "model", id });
    }

    // The next model, as the line's model button does.
    function cycleModel() {
        if (models.length < 2)
            return;
        const at = models.findIndex(m => m.id === model?.id);
        chooseModel(models[(at + 1) % models.length].id);
    }

    function grant(group: string) {
        request({ op: "grant", group });
    }

    function revoke(group: string) {
        request({ op: "revoke", group });
    }

    function setRetention(days: int) {
        request({ op: "retention", days });
    }

    function clearHistory() {
        request({ op: "clear-history" });
    }

    function setLoading(mode: string) {
        request({ op: "loading", mode });
    }

    // previous: the skill's name before, when changing one.
    function saveSkill(skill: var, previous: string) {
        skillError = "";
        request(Object.assign({ op: "save-skill", previous: previous || null }, skill));
    }

    // A provider's chat models, with the key typed, or the one kept.
    function listProvider(provider: string, key: string) {
        providerModels = Object.assign({}, providerModels, { [provider]: { listing: true } });
        request({ op: "provider-models", provider, key: key || null });
    }

    function addModel(provider: string, model: string, name: string, key: string) {
        addError = "";
        request({ op: "add-model", provider, model, name, key: key || null });
    }

    function removeModel(id: string) {
        request({ op: "remove-model", id });
    }

    // Continue with ChatGPT: the service gives the page, which opens in the
    // person's browser, and is told when the sign-in ends.
    function signInChatgpt() {
        signInError = "";
        signingIn = true;
        request({ op: "chatgpt-sign-in" });
    }

    function signOutChatgpt() {
        request({ op: "chatgpt-sign-out" });
    }

    function deleteSkill(name: string) {
        skillError = "";
        request({ op: "delete-skill", name });
    }

    // Downloads the model, through the one queue.
    function getModel() {
        if (extra)
            Extras.install(extra.id);
    }

    // The panel lists the conversations, or shows the one open.
    function list(on: bool) {
        found = null;
        query = "";
        listing = on;
    }

    // A message came or changed: an answer shows in the pill. The note
    // follows its message, as an action that waited is done.
    function arrived(message: var) {
        if (!Lock.locked && Logic.peeks(view, Shell.panel !== "", message))
            peek(message);
        else if (note?.id === message.id)
            note = message;
    }

    function receive(line: string) {
        let event;
        try {
            event = JSON.parse(line);
        } catch (e) {
            return;
        }
        switch (event.event) {
        case "state":
            conversations = event.conversations;
            applyStatus(event);
            applySettings(event);
            greeted = true;
            // The one open, or the latest, if it was not left for long.
            if (conversation)
                open(conversation.id);
            else if (conversations.length && Logic.continues(conversations[0].updated, Date.now() / 1000))
                open(conversations[0].id);
            break;
        case "tidy":
            tidied(event);
            break;
        case "voice":
            if (conversing)
                voiceConversation = event.conversation;
            else
                request({ op: "forget", id: event.conversation });
            break;
        case "sent":
            if (!event.ephemeral && conversation?.id !== event.conversation)
                open(event.conversation);
            break;
        case "conversation":
            conversation = { id: event.id, title: event.title, workspace: event.workspace, messages: event.messages };
            break;
        case "message":
            if (event.conversation === voiceConversation && voiceConversation) {
                voiceSent = false;
                const said = voiceMessages.slice();
                const at = said.findIndex(m => m.id === event.message.id);
                if (at >= 0)
                    said[at] = event.message;
                else
                    said.push(event.message);
                voiceMessages = said;
                tell(event.message);
            }
            if (conversation?.id === event.conversation) {
                const list = conversation.messages.slice();
                const at = list.findIndex(m => m.id === event.message.id);
                if (at >= 0)
                    list[at] = event.message;
                else
                    list.push(event.message);
                conversation = Object.assign({}, conversation, { messages: list });
                arrived(event.message);
            }
            break;
        case "conversations":
            conversations = event.conversations;
            if (conversation)
                conversation = Object.assign({}, conversation, { title: conversations.find(c => c.id === conversation.id)?.title ?? conversation.title });
            if (query.trim())
                search(query);
            break;
        case "status":
            applyStatus(event);
            break;
        case "settings":
            applySettings(event);
            break;
        case "provider-models":
            providerModels = Object.assign({}, providerModels, { [event.provider]: event.error ? { error: event.error } : { models: event.models } });
            break;
        case "model-added":
            addError = event.error ?? "";
            if (event.id)
                modelAdded(event.id);
            break;
        case "chatgpt":
            if (event.url) {
                Qt.openUrlExternally(event.url);
            } else {
                signingIn = false;
                signInError = event.error ?? "";
            }
            break;
        case "skill":
            skillError = event.error ?? "";
            if (event.name)
                skillSaved(event.name);
            break;
        case "deleted":
            deleted = { id: event.id, title: event.title };
            forget.restart();
            break;
        case "results":
            if (event.query === query)
                found = event.ids;
            break;
        }
    }

    function applyStatus(event: var) {
        status = event.status;
        busy = event.busy;
        queued = event.queued;
        attention = event.attention;
        model = event.model;
    }

    function applySettings(event: var) {
        models = event.models;
        grants = event.grants;
        groups = event.groups;
        retention = event.retention;
        loading = event.loading ?? "ready";
        skills = event.skills ?? [];
        tools = event.tools ?? [];
        providers = event.providers ?? ({});
        chatgpt = event.chatgpt ?? null;
    }

    // The sound is 0.3 s long: then voice mode hears again, unless it talks.
    Timer {
        id: gotItEnds
        interval: 400
        onTriggered: {
            if (assistant.conversing && listener.running && !assistant.talking)
                listener.write(JSON.stringify({ do: "resume" }) + "\n");
        }
    }

    Timer {
        id: voiceNoticeEnds
        interval: 4000
        onTriggered: assistant.voiceNotice = ""
    }

    // A second tap this soon after a tap is a double tap.
    Timer {
        id: doubleTap
        interval: Logic.doubleTapWithin
        onTriggered: assistant.key("late")
    }

    // Super held this long listens.
    Timer {
        id: hold
        interval: Logic.holdAfter
        onTriggered: assistant.key("held")
    }

    // Super never let go: the microphone does not stay open.
    Timer {
        id: longest
        interval: Logic.longestHold
        onTriggered: assistant.key("long")
    }

    // A note goes again, unless it waits for the person or the pointer is
    // on it.
    Timer {
        id: peekTimer
        interval: Logic.peekFor
        onTriggered: {
            if (!assistant.note)
                return;
            if (!Logic.peekEnds(assistant.attention, assistant.peekHovered)) {
                restart();
                return;
            }
            assistant.dropNote();
        }
    }

    // A word on the button goes by itself.
    Timer {
        running: assistant.notice !== ""
        interval: 4000
        onTriggered: assistant.notice = ""
    }

    // The assistant opened some other way: the note is in it.
    Connections {
        target: Shell

        function onPanelChanged() {
            if (Shell.panel === "assistant")
                assistant.dropNote();
        }
    }

    // Hears for the assistant (dictation/hear): it delivers
    // nowhere, and ends with what was said.
    Process {
        id: listener

        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => assistant.heard(line)
        }
        // Quickshell does not declare the status's type to tooling.
        onExited: exitCode => { // qmllint disable signal-handler-parameters
            if (assistant.voice !== "" && !selection.running)
                assistant.voice = "";
            assistant.voiceOff();
        }
    }

    // Says voice mode's answers aloud (dictation/speak), from when voice mode
    // begins, so its voices are loaded by the first answer.
    Process {
        id: speaker

        command: [assistant.tree ? `${assistant.tree}/../dictation/speak` : "/usr/libexec/desktop/speak",
            `${Quickshell.env("EXTRAS_DIR") || "/var/lib/extras"}/voices`]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                let message;
                try {
                    message = JSON.parse(line);
                } catch (e) {
                    return;
                }
                const talking = message.state === "speaking";
                if (talking === assistant.talking || !assistant.conversing)
                    return;
                assistant.talking = talking;
                if (listener.running)
                    listener.write(JSON.stringify({ do: talking ? "pause" : "resume" }) + "\n");
            }
        }
        // Quickshell does not declare the status's type to tooling.
        onExited: exitCode => { // qmllint disable signal-handler-parameters
            if (assistant.talking && listener.running)
                listener.write(JSON.stringify({ do: "resume" }) + "\n");
            assistant.talking = false;
        }
    }

    // The selected text, as the primary selection holds it; with `then`,
    // what was said goes on as a request once it is read.
    Process {
        id: selection

        property var then: null

        command: ["wl-paste", "--primary", "--no-newline", "--type", "text"]
        stdout: StdioCollector {
            id: selected
        }
        // Quickshell does not declare the status's type to tooling.
        onExited: exitCode => { // qmllint disable signal-handler-parameters
            const window = Hyprland.activeToplevel;
            const ipc = window?.lastIpcObject;
            assistant.context = Logic.context(exitCode === 0 ? selected.text : "", ipc?.class ?? "", window?.title ?? "", 4000);
            if (then !== null) {
                const said = then;
                then = null;
                assistant.voice = "";
                assistant.sendSpoken(said);
            }
        }
    }

    // Undo is offered for a while after a delete.
    Timer {
        id: forget
        interval: 8000
        onTriggered: assistant.deleted = null
    }

    // The connection: a new one for each attempt, as a socket that failed
    // to connect does not try again.
    property Socket socket: null

    Component {
        id: connection

        Socket {
            id: own

            path: assistant.path
            parser: SplitParser {
                onRead: line => assistant.receive(line)
            }
            onConnectedChanged: {
                if (assistant.socket !== own)
                    return;
                assistant.greeted = false;
                if (connected)
                    assistant.request({ op: "hello", pid: Quickshell.processId });
            }
        }
    }

    // Connects from the start, and again whenever the service went away,
    // until it has answered.
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: !assistant.greeted
        onTriggered: {
            if (assistant.tree && !server.running) {
                server.environment = { ASSISTANT_SOCKET: assistant.path };
                server.running = true;
            }
            assistant.socket?.destroy();
            assistant.socket = connection.createObject(assistant);
            assistant.socket.connected = true;
        }
    }

    // In development only: the assistant from the source tree. It ends with
    // the shell, however the shell ends, so the next one never meets it.
    Process {
        id: server
        command: ["setpriv", "--pdeathsig", "TERM", `${assistant.tree}/../assistant/assistant`, "serve"]
    }

    // In development only: the model's server, which systemd starts on
    // demand in the installed system (assistant/language-model@.socket). Here
    // it starts with the first request, where the assistant looks for it
    // (assistant/models.py), and ends with the shell. `make dev-assistant`
    // provides it (ASSISTANT_LLAMA).
    readonly property string llama: tree ? Quickshell.env("ASSISTANT_LLAMA") ?? "" : ""
    property bool modelWanted
    // A model kept ready loads a little after the start, as the service has
    // it (language-model-ready@.service); here it stays until the shell ends.
    Timer {
        running: assistant.llama !== "" && assistant.loading === "ready"
        interval: 30000
        onTriggered: assistant.modelWanted = true
    }
    Process {
        running: assistant.llama !== "" && assistant.modelWanted && assistant.ready && assistant.model?.where === "local"
        command: ["sh", "-c", 'rm -f "$3"; vision=; [ -f "$4" ] && vision=--mmproj; '
            + 'LD_LIBRARY_PATH=$(dirname "$1") exec setpriv --pdeathsig TERM "$1" --model "$2" --host "$3" ${vision:+"$vision" "$4"} '
            + "--jinja --reasoning off --ctx-size 8192 --parallel 1 --no-webui", "llama", assistant.llama,
            `${Quickshell.env("EXTRAS_DIR")}/${assistant.model?.extra}/model.gguf`,
            `${Quickshell.env("XDG_RUNTIME_DIR")}/language-model-${assistant.model?.extra}.sock`,
            `${Quickshell.env("EXTRAS_DIR")}/${assistant.model?.extra}-vision/mmproj.gguf`]
    }

    // A model downloaded, or removed, changes what is ready.
    Connections {
        target: Extras

        function onListChanged() {
            assistant.request({ op: "models" });
        }
    }

    // Nothing new starts while the screen is locked; what is under way goes on.
    Connections {
        target: Lock

        function onLockedChanged() {
            assistant.request({ op: "locked", locked: Lock.locked });
            if (Lock.locked) {
                // The panel comes back with the unlock; nothing is heard.
                assistant.endListening(false);
                assistant.keyState = "idle";
                assistant.dropNote();
                assistant.listing = false;
            }
        }
    }

    // What the assistant asks of the shell (assistant/actions.py):
    // qs ipc --pid PID call assistant FUNCTION ARGS.
    IpcHandler {
        target: "assistant"

        function toggle(): void {
            assistant.tap(Shortcuts.focused, null);
        }

        // The Super key: "down", "other", "held", or "up".
        function key(event: string): void {
            assistant.key(event);
        }

        function panel(): void {
            assistant.openPanel(Shortcuts.focused);
        }

        function dock(docked: bool): void {
            assistant.dock(docked, false);
        }

        function hide(): void {
            assistant.hide();
        }

        // "", "bubbles", "panel", or "docked".
        function mode(): string {
            return assistant.view.open === "panel" && assistant.view.docked ? "docked" : assistant.view.open;
        }

        // "", "listening", or "writing".
        function voiceState(): string {
            return assistant.voice;
        }

        // Why it does not listen, as the button says it, or "".
        function notice(): string {
            return assistant.notice;
        }

        function doNotDisturb(): bool {
            return Settings.doNotDisturb;
        }

        function setDoNotDisturb(on: bool): void {
            Notifications.setQuiet(on ? "Until turned off" : "");
        }

        // The layout's code, such as "us".
        function keyboardLayout(): string {
            return Keyboard.layouts[Keyboard.active] ?? "";
        }

        // A layout in use, by its code or its language's, such as "pl"; false
        // if it is none of them.
        function setKeyboardLayout(code: string): bool {
            const at = Keyboard.layouts.findIndex(l => l === code || Keyboard.languageOf(l).toLowerCase() === code);
            if (at < 0)
                return false;
            Keyboard.select(at);
            return true;
        }

        function launch(id: string): bool {
            const entry = DesktopEntries.byId(id.replace(/\.desktop$/, ""));
            if (!entry)
                return false;
            entry.execute();
            return true;
        }

        function moveWindow(workspace: int): bool {
            if (!Hyprland.activeToplevel)
                return false;
            Compositor.dispatch(`function() workspaces.send(${workspace}) end`);
            return true;
        }

        // "area", "window", or "screen": the capture overlay, as Print opens it.
        function capture(target: string): void {
            Shortcuts.capture(target === "window" ? "capture-window" : target === "screen" ? "capture-screen" : "capture");
        }

        function lock(): void {
            Lock.lock();
        }

        // A web page, in the person's browser.
        function openUrl(url: string): void {
            Qt.openUrlExternally(url);
        }

        // The applications with an icon on the bar, one name a line.
        function backgroundApps(): string {
            return SystemTray.items.values.map(i => i.title || i.tooltipTitle || i.id).filter(n => n).join("\n");
        }
    }
}
