// The store of Settings > Apps: the apps installed, those on offer, and what
// is being installed or removed, through the one queue (Downloads.qml), which
// goes on if Settings closes. The work is out of the shell's process:
// apps/app-catalog reads, and the queue's apps/app-install and apps/app-remove
// install and remove.
pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: apps

    // Each installed app: { id, name, summary, icon, version, size, removable,
    // browser, builtIn }; and why they couldn't be listed.
    property var installed: []
    property string installedError
    property bool listed
    // What a search found: { id, name, summary, icon };
    // whether it is looking, and why it couldn't.
    property var found: []
    property string query
    // The category shown, by its AppStream name, or "" for all; how many to
    // show; and whether there are more.
    property string category
    readonly property int pageSize: 48
    property int limit: pageSize
    property bool more
    property bool searching: finder.running || refresher.running || searchDelay.running
    property string findError
    // The app whose details show, with whether they have come.
    property var shown: ({})
    property bool shownLoading
    // What is under way or failed, by app id, from the queue: { action:
    // "install" or "remove", note, error }.
    readonly property var work: {
        const byId = {};
        for (const job of Downloads.jobs) {
            if (job.kind !== "app")
                continue;
            if (job.state === "queued")
                byId[job.target] = { action: job.action, note: "Waiting" };
            else if (job.state === "running")
                byId[job.target] = { action: job.action, note: job.percent > 0 ? `${job.note} ${job.percent}%` : job.note };
            else if (job.state === "failed")
                byId[job.target] = { action: job.action, note: "", error: job.error };
        }
        for (const key of Downloads.pending) {
            if (key.startsWith("app:"))
                byId[key.slice("app:".length)] = { action: "install", note: "Waiting" };
        }
        return byId;
    }

    // The helpers: the source tree's in development (make run), otherwise the
    // installed ones.
    function helper(name: string): string {
        const tree = Quickshell.env("DESKTOP_SHELL");
        return tree ? `${tree}/../apps/${name}` : `/usr/libexec/desktop/${name}`;
    }

    function byId(id: string): var {
        return installed.find(a => a.id === id) ?? null;
    }

    // Settings > Apps has opened.
    function open() {
        lister.running = true;
        refresher.running = true;
    }

    function search(text: string) {
        query = text.trim();
        limit = pageSize;
        searchDelay.restart();
    }

    function pickCategory(name: string) {
        category = name;
        limit = pageSize;
        find();
    }

    function showMore() {
        limit += pageSize;
        find();
    }

    function find() {
        if (refresher.running)
            return;
        // A search under way is answered, then this one runs (finder).
        if (finder.running) {
            finder.again = true;
            return;
        }
        finder.command = [helper("app-catalog"), "search", ...(category ? ["--category", category] : []),
            "--limit", String(limit), ...query.split(/\s+/).filter(w => w)];
        finder.running = true;
    }

    // Shows an app's details, at once with what a list knows of it.
    function show(app: var) {
        shown = app;
        shownLoading = true;
        lookUp();
    }

    // A look under way for another app stops first (details).
    function lookUp() {
        if (details.running) {
            details.running = false;
            return;
        }
        details.looking = shown.id;
        details.command = [helper("app-catalog"), "details", shown.id];
        details.running = true;
    }

    // An app's name, for the queue, from what lists it.
    function nameOf(id: string): string {
        return [shown, ...found, ...installed].find(a => a?.id === id)?.name ?? id;
    }

    function install(id: string) {
        Downloads.add("app", "install", id, nameOf(id), false);
    }

    function remove(id: string, deleteData: bool) {
        Downloads.add("app", "remove", id, nameOf(id), deleteData);
    }

    // The list shows what is true once the queue's work on an app ends.
    Connections {
        target: Downloads

        function onEnded(job: var) {
            if (["app", "browser", "update"].includes(job.kind))
                lister.running = true;
        }
    }

    Timer {
        id: searchDelay
        interval: 200
        onTriggered: apps.find()
    }

    Process {
        id: lister
        command: [apps.helper("app-catalog"), "installed"]
        stdout: StdioCollector {
            onStreamFinished: {
                const answer = JSON.parse(text || `{"error": "Apps couldn't be listed"}`);
                apps.installed = answer.apps ?? [];
                apps.installedError = answer.error ?? "";
                apps.listed = true;
            }
        }
    }
    // The first list of apps after the catalogue has come.
    Process {
        id: refresher
        command: [apps.helper("app-catalog"), "refresh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const answer = JSON.parse(text || `{"error": "The list of apps couldn't be updated"}`);
                // An older download still answers searches (find).
                apps.findError = answer.error ?? "";
            }
        }
        onRunningChanged: {
            if (!running)
                apps.find();
        }
    }
    Process {
        id: finder

        property bool again

        stdout: StdioCollector {
            onStreamFinished: {
                const answer = JSON.parse(text || `{"error": "The search stopped"}`);
                apps.found = answer.apps ?? [];
                apps.more = answer.more ?? false;
                if (answer.error)
                    apps.findError = answer.error;
                else if (answer.apps)
                    apps.findError = "";
            }
        }
        onRunningChanged: {
            if (!running && again) {
                again = false;
                apps.find();
            }
        }
    }
    Process {
        id: details

        property string looking

        onRunningChanged: {
            if (!running && looking !== apps.shown.id)
                apps.lookUp();
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const answer = JSON.parse(text || "{}");
                if (answer.app?.id !== apps.shown.id)
                    return;
                if (answer.app) {
                    // What a list said stands where the catalogue has nothing.
                    apps.shown = Object.assign({}, apps.shown, ...Object.entries(answer.app)
                        .filter(([, value]) => value !== "").map(([key, value]) => ({ [key]: value })));
                }
                apps.shownLoading = false;
            }
        }
    }
}
