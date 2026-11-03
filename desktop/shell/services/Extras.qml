// What can be downloaded beyond the OS (extras/extra), for Welcome and Settings >
// Assistant: listed here, downloaded and removed through the one queue
// (Downloads.qml), which goes on if the window that asked closes, until
// cancelled.
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
    // By id, from the queue: { state: "queued", "working", or "failed"; note;
    // percent }.
    readonly property var progress: {
        const byId = {};
        for (const job of Downloads.jobs) {
            if (job.kind !== "extra")
                continue;
            if (job.state === "queued")
                byId[job.target] = { state: "queued", note: "Waiting", percent: 0 };
            else if (job.state === "running")
                byId[job.target] = { state: "working", note: job.note, percent: job.percent };
            else if (job.state === "failed")
                byId[job.target] = { state: "failed", note: job.error, percent: 0 };
        }
        for (const key of Downloads.pending) {
            if (key.startsWith("extra:"))
                byId[key.slice("extra:".length)] = { state: "queued", note: "Waiting", percent: 0 };
        }
        return byId;
    }

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

    function nameOf(id: string): string {
        return list.find(e => e.id === id)?.name ?? id;
    }

    function install(id: string) {
        Downloads.add("extra", "install", id, nameOf(id), false);
    }

    function remove(id: string) {
        Downloads.add("extra", "remove", id, nameOf(id), false);
    }

    // Stops those named, queued or under way; what was downloaded stays, for
    // the next try to go on from (extras/extra).
    function cancel(ids: list<string>) {
        Downloads.cancel(ids.map(id => `extra:${id}`));
    }

    Component.onCompleted: refresh()

    // What is installed changes as the queue's work ends.
    Connections {
        target: Downloads

        function onEnded(job: var) {
            if (job.kind === "extra")
                extras.refresh();
        }
    }

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
}
