// The assistant, as the shell shows it, as in the demo: the command line near
// the top (bar/AssistantPanel.qml) answers in place; the sidebar
// (bar/AssistantSidebar.qml) holds a whole conversation; and all of them are
// listed, with search, over the screen (bar/AssistantConversations.qml).
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

Singleton {
    id: assistant

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
    // { id, name, mark, color, where, extra, ready }, or null.
    property var model: null
    property var models: []
    // The groups allowed, and every group's description, by id.
    property list<string> grants
    property var groups: ({})
    // Days the activity log keeps; 0 is for ever.
    property int retention: 30
    // The conversation deleted last, { id, title }, for Undo.
    property var deleted: null
    // The search's ids, or null with no search.
    property var found: null
    property string query

    // Where the sidebar and the list of conversations are open, by screen
    // name, or "".
    property string sidebarOn
    property string listOn
    // The line's question, and whether it shows the answer.
    property string asked
    readonly property bool answering: busy || messages.some(m => m.state === "proposed")
    // The model's extra, and how its download goes (Extras.qml).
    readonly property var extra: Extras.list.find(e => e.id === model?.extra) ?? null
    readonly property var download: extra ? Extras.progress[extra.id] ?? null : null
    readonly property bool ready: model?.ready ?? false
    // That an AI answers, wherever the assistant is used: people must know (the EU's
    // AI Act, article 50).
    readonly property string disclosure: model?.where === "online"
        ? "Answers come from an online AI model, and can be wrong."
        : "Answers come from an AI model on this computer, and can be wrong."

    function request(fields: var) {
        if (!socket?.connected)
            return;
        socket.write(JSON.stringify(fields) + "\n");
        socket.flush();
    }

    function workspaceName(): string {
        const workspace = Hyprland.focusedMonitor?.activeWorkspace;
        return workspace ? String(workspace.name ?? workspace.id) : "";
    }

    // A new request: in the open conversation, or a new one.
    function send(text: string) {
        text = text.trim();
        if (!text)
            return;
        request({ op: "send", id: conversation?.id ?? null, text, workspace: workspaceName() });
    }

    // The line asks anew: a conversation of its own, its answer in place.
    function ask(text: string) {
        text = text.trim();
        if (!text)
            return;
        conversation = null;
        asked = text;
        send(text);
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
        asked = "";
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

    // Downloads the model, through the one queue.
    function getModel() {
        if (extra)
            Extras.install(extra.id);
    }

    // Opens or closes the line on a screen, by name.
    function toggleLine(screen: string) {
        Shell.request("assistant", screen);
    }

    // Goes on in the sidebar, with the line's conversation.
    function openSidebar(screen: string) {
        Shell.close();
        listOn = "";
        sidebarOn = screen;
    }

    function openList(screen: string) {
        Shell.close();
        found = null;
        query = "";
        listOn = screen;
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
            if (conversation)
                open(conversation.id);
            break;
        case "sent":
            if (conversation?.id !== event.conversation)
                open(event.conversation);
            break;
        case "conversation":
            conversation = { id: event.id, title: event.title, workspace: event.workspace, messages: event.messages };
            break;
        case "message":
            if (conversation?.id === event.conversation) {
                const list = conversation.messages.slice();
                const at = list.findIndex(m => m.id === event.message.id);
                if (at >= 0)
                    list[at] = event.message;
                else
                    list.push(event.message);
                conversation = Object.assign({}, conversation, { messages: list });
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

    // In development only: the assistant from the source tree.
    Process {
        id: server
        command: [`${assistant.tree}/../assistant/assistant`, "serve"]
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
                assistant.sidebarOn = "";
                assistant.listOn = "";
            }
        }
    }

    // What the assistant asks of the shell (assistant/actions.py):
    // qs ipc --pid PID call assistant FUNCTION ARGS.
    IpcHandler {
        target: "assistant"

        function toggle(): void {
            assistant.toggleLine(Shortcuts.focused);
        }

        function doNotDisturb(): bool {
            return Settings.doNotDisturb;
        }

        function setDoNotDisturb(on: bool): void {
            Settings.doNotDisturb = on;
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
    }
}
