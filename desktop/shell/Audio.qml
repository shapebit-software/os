// The default sound output and input, with their volume and mute state.
pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    readonly property PwNode output: Pipewire.defaultAudioSink
    readonly property PwNode input: Pipewire.defaultAudioSource

    // Volume and mute state are only kept current for tracked nodes.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
}
