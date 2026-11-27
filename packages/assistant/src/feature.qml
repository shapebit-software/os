// What the assistant adds to the shell (packages/shell/src/services/Feature.qml),
// which its package installs as the shell's features/assistant.qml, with its
// QML as the module qs.assistant beside it: Settings > Assistant and its pages,
// its panel and the edge that opens it, its voice mode's pill, its button on
// the bars and in the hot corner, Super, and the tidying up of dictated text.
import QtQuick
import qs.assistant
import qs.services

Feature {
    id: feature

    // The assistant answers the actions it asks of the shell from the start.
    readonly property bool connected: Assistant.connected
    // The extras of Settings > Assistant: the model's first, then its vision
    // projector, then the rest, such as dictation's, which voice needs.
    readonly property var assistantExtras: {
        const model = Assistant.model?.extra ?? "";
        const rank = e => e.id === model ? 0 : e.id === `${model}-vision` ? 1 : 2;
        return Extras.list.slice().sort((a, b) => rank(a) - rank(b));
    }
    // The memory a local model holds while loaded: its files, read into
    // memory, and room for the conversation.
    readonly property string modelMemory: {
        const extra = Extras.list.find(e => e.id === Assistant.model?.extra);
        const vision = Extras.list.find(e => e.id === `${Assistant.model?.extra}-vision` && e.installed);
        return `${(((extra?.bytes ?? 0) + (vision?.bytes ?? 0) + 1300000000) / 1e9).toFixed(1)} GB`;
    }

    name: "assistant"
    sections: [
        // The models and the downloads of the one on this computer, how it
        // loads, what it can do, and what it may do unasked; then where it shows.
        { id: "assistant", name: "Assistant", icon: Assistant.icon, group: 0, after: "account", rows: [
            { label: "Models", detail: "Gemma on this computer",
              value: Assistant.model?.name ?? "None", open: () => Features.openPage("assistant-models") },
            ...assistantExtras.map(e => ({ label: e.name, detail: e.detail, kind: "extra", extra: e })),
            ...(Assistant.model?.where === "local" ? [{ label: "Load the model", kind: "choice",
              detail: Assistant.loading === "used"
                  ? `When first asked, which takes some seconds; it frees about ${modelMemory} of memory after 10 minutes unused`
                  : `Shortly after sign-in, to answer at once; it keeps about ${modelMemory} of memory in use`,
              options: ["After sign-in", "When used"], selected: Assistant.loading === "used" ? "When used" : "After sign-in",
              select: o => Assistant.setLoading(o === "When used" ? "used" : "ready") }] : []),
            { label: "Sound when it hears you", detail: "A soft sound as soon as it takes what you said, before the answer comes",
              kind: "toggle", on: Settings.assistantSounds, toggle: () => Settings.assistantSounds = !Settings.assistantSounds },
            ...(Dictation.available ? [{ label: "Load the speech model", kind: "choice",
              detail: Settings.speechModel === "ready"
                  ? "For dictation and voice: shortly after sign-in, to hear at once; it keeps about 1.1 GB of memory in use"
                  : "For dictation and voice: when first used, which takes about two seconds; it frees about 1.1 GB of memory once unused",
              options: ["After sign-in", "When used"], selected: Settings.speechModel === "ready" ? "After sign-in" : "When used",
              select: o => Settings.speechModel = o === "When used" ? "used" : "ready" }] : []),
            ...(Dictation.available && Settings.speechModel === "used" ? [{ label: "Free the speech model", kind: "choice",
              detail: "After this long without dictation or voice",
              options: ["5 min", "10 min", "20 min", "1 hour"],
              selected: Settings.speechModelMinutes === 60 ? "1 hour" : `${Settings.speechModelMinutes} min`,
              select: o => Settings.speechModelMinutes = o === "1 hour" ? 60 : parseInt(o) }] : []),
            { label: "Skills and tools", detail: "What the assistant knows how to do, and skills of your own",
              value: `${Assistant.skills.length} ${Assistant.skills.length === 1 ? "skill" : "skills"} · ${Assistant.tools.length} tools`,
              open: () => Features.openPage("assistant-skills") },
            { label: "Permissions", detail: "What it may do without asking, and the activity log",
              value: `${Assistant.grants.length} of ${Object.keys(Assistant.groups).length} allowed`,
              open: () => Features.openPage("assistant-permissions") },
            { label: "Panel beside the windows", detail: "The assistant's panel takes its own room at the right, and windows retile beside it",
              kind: "toggle", on: Settings.assistantDocked, toggle: () => Settings.assistantDocked = !Settings.assistantDocked },
            { label: "Right edge opens the panel", detail: "Push the pointer against the middle of the screen's right edge",
              kind: "toggle", on: Settings.assistantEdge, toggle: () => Settings.assistantEdge = !Settings.assistantEdge },
        ] }
    ]
    pages: ({
        "assistant-models": { title: "Models", section: "assistant", component: modelsPage },
        "assistant-skills": { title: "Skills and tools", section: "assistant", component: skillsPage },
        "assistant-permissions": { title: "Permissions", section: "assistant", rows: [
            // What the assistant may do without asking; the rest asks every time.
            ...Object.keys(Assistant.groups).map(g => ({ label: Assistant.groups[g], kind: "toggle",
              detail: Assistant.grants.includes(g) ? "Without asking" : "Asks first, on its card",
              on: Assistant.grants.includes(g), toggle: () => Assistant.grants.includes(g) ? Assistant.revoke(g) : Assistant.grant(g) })),
            { label: "Activity log", detail: "What the assistant did and what it was allowed, kept on this computer", kind: "choice",
              options: ["7 days", "30 days", "90 days", "Always"],
              selected: Assistant.retention === 0 ? "Always" : `${Assistant.retention} days`,
              select: o => Assistant.setRetention(o === "Always" ? 0 : parseInt(o)) },
            { label: "Clear the activity log", detail: "Conversations stay; delete them from the assistant's list", value: "Clear",
              open: () => Assistant.clearHistory() },
        
        ] },
    })
    surfaces: [dock, edge, voicePill]
    panels: [bubbles]
    // Super alone: a tap opens the assistant, held it listens (Assistant.qml).
    shortcuts: ({
        "super-down": () => Assistant.key("down"),
        "super-other": () => Assistant.key("other"),
        "super-up": () => Assistant.key("up"),
    })
    items: ({ assistant: { icon: Assistant.icon, component: barButton } })
    // In the hot corner: what was open last, its bubbles there or its panel.
    actions: [{ name: "assistant", icon: Assistant.icon,
        tap: (screen, rect) => Assistant.tap(screen, () => Shell.toggle("assistant", screen, rect, "Bottom",
            Theme.stripHeight + Theme.gap)) }]
    voice: Assistant.voice !== "" ? { listening: Assistant.voice === "listening",
        writing: Assistant.voice === "writing", level: Assistant.level } : null
    // Dictation's Tidy up: the model writes the text again; reply hears each
    // part of what it writes (Assistant.tidied).
    provides: ({ tidy: (id, text, reply) => {
        tidyReply = reply;
        Assistant.tidy(id, text);
    } })
    property var tidyReply: null
    property Connections tidied: Connections {
        target: Assistant

        function onTidied(event: var) {
            if (feature.tidyReply)
                feature.tidyReply(event);
        }
    }
    onClickedOff: Assistant.clickedOff()

    property Component modelsPage: Component { AssistantModelsPage {} }
    property Component skillsPage: Component { AssistantSkillsPage {} }
    property Component barButton: Component { AssistantBarButton {} }
    property Component dock: Component { AssistantDock {} }
    property Component edge: Component { AssistantEdge {} }
    property Component voicePill: Component { VoicePill {} }
    property Component bubbles: Component { AssistantBubbles {} }
}
