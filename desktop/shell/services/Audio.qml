// The default sound output and input, with their volume and mute state; and,
// while any application records from the input, how loud it hears, for the
// bar's microphone (session/microphone-level). The level is measured only then,
// and nothing of the sound is kept.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: audio

    readonly property PwNode output: Pipewire.defaultAudioSink
    readonly property PwNode input: Pipewire.defaultAudioSource
    // The streams that record from the input, but the meter's own.
    readonly property var recorders: inputLinks.linkGroups.filter(g => g.source === input && g.target?.name !== "microphone-level")
    readonly property bool recording: recorders.length > 0
    // From 0 to 1, while recording; 0 otherwise.
    property real level

    readonly property string tree: Quickshell.env("DESKTOP_SHELL") ?? ""

    // Volume and mute state are only kept current for tracked nodes.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource, ...inputLinks.linkGroups.map(g => g.target)]
    }
    PwNodeLinkTracker {
        id: inputLinks
        node: Pipewire.defaultAudioSource
    }

    Process {
        running: audio.recording && !(audio.input?.audio?.muted ?? false)
        command: ["setpriv", "--pdeathsig", "TERM",
            audio.tree ? `${audio.tree}/../session/microphone-level` : "/usr/libexec/desktop/microphone-level"]
        stdout: SplitParser {
            onRead: line => audio.level = Number(line) || 0
        }
        onRunningChanged: {
            if (!running)
                audio.level = 0;
        }
    }
}
