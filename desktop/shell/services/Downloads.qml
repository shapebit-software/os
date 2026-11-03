// The one queue of what the desktop downloads and installs (downloads/downloads):
// apps and browsers, for Welcome and Settings > Apps, extras, for Welcome and
// Settings > Assistant, and the daily app updates, all shown in Settings >
// Downloads. The queue's
// helper does the work in a user service of its own, so it goes on if the
// shell stops; this reads the state it writes, and asks it to add, cancel, and
// clear.
pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: downloads

    // Each job, as downloads/downloads writes it, in the order added.
    property var jobs: []
    // The keys being added, until the state has them.
    property list<string> pending
    readonly property var active: jobs.filter(j => j.state === "queued" || j.state === "running")
    readonly property bool busy: active.length > 0 || pending.length > 0
    readonly property bool anyEnded: jobs.some(j => !["queued", "running"].includes(j.state))

    // A job that has ended, for those that look again then, as Apps and
    // Extras do.
    signal ended(var job)

    // The source tree's helper in development (make run), otherwise the
    // installed one.
    readonly property string helper: Quickshell.env("DESKTOP_SHELL")
        ? `${Quickshell.env("DESKTOP_SHELL")}/../downloads/downloads`
        : "/usr/libexec/desktop/downloads"
    readonly property string directory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/desktop"

    function byKey(key: string): var {
        return jobs.find(j => j.key === key) ?? null;
    }

    // kind: "app", "browser", "extra", or "update"; action: "install" or
    // "remove".
    function add(kind: string, action: string, target: string, name: string, deleteData: bool) {
        const key = `${kind}:${target}`;
        pending = [...pending, key];
        call.createObject(downloads, { key, command: [helper, "add", kind, action, target, name,
            ...(deleteData ? ["--delete-data"] : [])] });
    }

    function retry(job: var) {
        add(job.kind, job.action, job.target, job.name, job.deleteData ?? false);
    }

    function cancel(keys: list<string>) {
        if (keys.length > 0)
            call.createObject(downloads, { command: [helper, "cancel", ...keys] });
    }

    function clear() {
        call.createObject(downloads, { command: [helper, "clear"] });
    }

    // How a job goes, in a few words.
    function describe(job: var): string {
        switch (job.state) {
        case "queued":
            return "Waiting";
        case "running":
            return job.percent > 0 ? `${job.note} ${job.percent}%` : `${job.note}…`;
        case "done":
            return job.action === "remove" ? "Removed" : "Done";
        case "failed":
            return job.error || "Failed";
        default:
            return "Cancelled";
        }
    }

    // A half-written state, read while the helper writes it, is read again
    // when it is whole.
    function load(text: string) {
        let next;
        try {
            next = JSON.parse(text).jobs ?? [];
        } catch (e) {
            return;
        }
        const before = jobs;
        jobs = next;
        for (const job of next) {
            const was = before.find(j => j.key === job.key);
            if (["done", "failed", "cancelled"].includes(job.state) && was && ["queued", "running"].includes(was.state))
                ended(job);
        }
    }

    // The state is made before it is watched, which it must be to be watched.
    Component.onCompleted: maker.running = true

    Process {
        id: maker
        command: ["sh", "-c", `mkdir -p "$1" && touch "$1/downloads.json"`, "sh", downloads.directory]
        onRunningChanged: {
            if (!running)
                state.path = `${downloads.directory}/downloads.json`;
        }
    }

    FileView {
        id: state

        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: downloads.load(text())
    }

    // One call of the helper; an add is pending until it has written.
    Component {
        id: call

        Process {
            id: process

            property string key

            running: true
            onRunningChanged: {
                if (running)
                    return;
                state.reload();
                if (key)
                    downloads.pending = downloads.pending.filter(k => k !== key);
                destroy();
            }
        }
    }
}
