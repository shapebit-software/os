// What can be downloaded beyond the OS (extras/extra), for Welcome and Settings >
// Assistant: one at a time, going on if the window that asked closes.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: extras

    // Each: { id, name, detail, bytes, installed }.
    property var list: []
    property bool listed
    // Whether this person may download them.
    property bool writable
    readonly property var missing: list.filter(e => !e.installed)
    // By id: { state: "queued", "working", or "failed"; note; percent }.
    property var progress: ({})
    property var queue: []
    property string current
    readonly property bool busy: current !== "" || queue.length > 0

    function helper(): string {
        const tree = Quickshell.env("DESKTOP_SHELL");
        return tree ? `${tree}/../extras/extra` : "/usr/libexec/desktop/extra";
    }

    function refresh() {
        lister.running = true;
    }

    function sizeOf(extra: var): string {
        const megabytes = extra.bytes / 1000000;
        return megabytes >= 1000 ? `${(megabytes / 1000).toFixed(1)} GB` : `${Math.round(megabytes)} MB`;
    }

    function set(id: string, value: var) {
        const changed = Object.assign({}, progress);
        if (value)
            changed[id] = value;
        else
            delete changed[id];
        progress = changed;
    }

    function request(action: string, id: string) {
        if (id === current || queue.some(q => q[1] === id))
            return;
        set(id, { state: "queued", note: "Waiting", percent: 0 });
        queue = [...queue, [action, id]];
        next();
    }

    function install(id: string) {
        request("install", id);
    }

    function remove(id: string) {
        request("remove", id);
    }

    function next() {
        if (worker.running || queue.length === 0)
            return;
        const [action, id] = queue[0];
        queue = queue.slice(1);
        current = id;
        set(id, { state: "working", note: action === "install" ? "Starting" : "Removing", percent: 0 });
        worker.answered = false;
        worker.command = [helper(), action, id];
        worker.running = true;
    }

    function heard(line: string) {
        const message = JSON.parse(line);
        if (message.step) {
            set(current, { state: "working", note: message.step, percent: message.percent ?? 0 });
        } else if (message.done !== undefined) {
            worker.answered = true;
            set(current, null);
        } else if (message.error !== undefined) {
            worker.answered = true;
            set(current, { state: "failed", note: message.error, percent: 0 });
        }
    }

    Component.onCompleted: refresh()

    Process {
        id: lister

        command: [extras.helper(), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const answer = JSON.parse(text || '{"extras": []}');
                extras.list = answer.extras;
                extras.writable = answer.writable ?? false;
                extras.listed = true;
            }
        }
    }

    Process {
        id: worker

        property bool answered

        stdout: SplitParser {
            onRead: line => extras.heard(line)
        }
        // It ends having said how it went, unless it stopped.
        onRunningChanged: {
            if (running)
                return;
            if (!answered)
                extras.set(extras.current, { state: "failed", note: "It stopped. Try again.", percent: 0 });
            extras.current = "";
            extras.refresh();
            extras.next();
        }
    }
}
