// The store of Settings > Apps: the apps installed, those on offer, and what
// is being installed or removed, which goes on, one at a time, if Settings
// closes. The work is out of the shell's process: session/app-catalog reads,
// session/app-install installs, and session/app-remove removes.
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
    // What is under way, by app id: { action: "install" or "remove", note,
    // error }; and what waits, as { id, action, deleteData }.
    property var work: ({})
    property var queue: []
    property string working

    // The helpers: the source tree's in development (make run), otherwise the
    // installed ones.
    function helper(name: string): string {
        const tree = Quickshell.env("DESKTOP_SHELL");
        return tree ? `${tree}/../session/${name}` : `/usr/libexec/desktop/${name}`;
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

    function setWork(id: string, entry: var) {
        const next = Object.assign({}, work);
        if (entry)
            next[id] = entry;
        else
            delete next[id];
        work = next;
    }

    function enqueue(id: string, action: string, deleteData: bool) {
        if (work[id] && !work[id].error)
            return;
        setWork(id, { action, note: "Waiting" });
        queue = [...queue, { id, action, deleteData }];
        runNext();
    }

    function install(id: string) {
        enqueue(id, "install", false);
    }

    function remove(id: string, deleteData: bool) {
        enqueue(id, "remove", deleteData);
    }

    function runNext() {
        if (worker.running || queue.length === 0)
            return;
        const next = queue[0];
        queue = queue.slice(1);
        working = next.id;
        setWork(next.id, { action: next.action, note: next.action === "install" ? "Installing" : "Removing" });
        worker.command = next.action === "install"
            ? [helper("app-install"), "apps", next.id]
            : [helper("app-remove"), next.id, ...(next.deleteData ? ["--delete-data"] : [])];
        worker.running = true;
    }

    function heard(line: string) {
        const message = JSON.parse(line);
        if (message.done !== undefined)
            setWork(working, null);
        else if (message.error !== undefined)
            setWork(working, Object.assign({}, work[working], { error: message.error }));
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
    Process {
        id: worker
        stdout: SplitParser {
            onRead: line => apps.heard(line)
        }
        // It ends having said how it went, unless it stopped; the list then
        // shows what is true, and the next starts.
        onRunningChanged: {
            if (running)
                return;
            if (apps.work[apps.working] && !apps.work[apps.working].error)
                apps.setWork(apps.working, Object.assign({}, apps.work[apps.working], { error: "It stopped before it finished" }));
            apps.working = "";
            lister.running = true;
            apps.runNext();
        }
    }
}
