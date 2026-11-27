pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Capture's settings, kept in ~/.config/desktop/capture.json (SettingsFile.qml).
Singleton {
    // Whether a screenshot opens for markup before it is saved; whether
    // screen recordings take sound from the microphone, and show the camera
    // in a bubble; whether camera recordings take sound from the microphone;
    // whether voice and camera recordings skip their silences
    // (capture/src/skip-silence); and whether an application may share what
    // was picked again without asking (SharePicker.qml).
    property alias markup: adapter.markup
    property alias microphone: adapter.microphone
    property alias bubble: adapter.bubble
    property alias cameraMicrophone: adapter.cameraMicrophone
    property alias skipSilence: adapter.skipSilence
    property alias shareRemember: adapter.shareRemember

    SettingsFile {
        name: "capture"

        // Quickshell does not declare the adapter's type to tooling.
        JsonAdapter { // qmllint disable unresolved-type
            id: adapter

            property bool markup: false
            property bool microphone: false
            property bool bubble: false
            property bool cameraMicrophone: true
            property bool skipSilence: false
            property bool shareRemember: false
        }
    }
}
