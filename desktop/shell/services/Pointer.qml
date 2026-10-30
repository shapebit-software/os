// The mice and touchpads, and their settings (Settings.qml) applied to the
// compositor when they load and when they change: tap to click and natural
// scrolling on touchpads, natural scrolling on mice, and the speed of each,
// the touchpads' set on each touchpad, since one speed applies to all the
// rest. A touchpad is a pointer named as one, as libinput names them.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: pointer

    // The touchpads' names, as the compositor knows them.
    property list<string> touchpads
    // The settings in the compositor's terms, so that a change applies them.
    readonly property string config: `function() hl.config({ input = {
        sensitivity = ${Settings.mouseSpeed.toFixed(2)},
        natural_scroll = ${Settings.mouseNaturalScroll},
        touchpad = { tap_to_click = ${Settings.tapToClick}, natural_scroll = ${Settings.touchpadNaturalScroll} },
    } }) end`
    readonly property string devices: touchpads.map(name =>
        `hl.device({ name = ${Compositor.quote(name)}, sensitivity = ${Settings.touchpadSpeed.toFixed(2)} })`).join(" ")

    // Looks for mice and touchpads again, as when Settings opens.
    function refresh() {
        list.running = true;
    }

    // As the settings load (Settings.apply), and then on every change.
    function apply() {
        Compositor.dispatch(config);
        applyDevices();
    }

    function applyDevices() {
        if (devices)
            Compositor.dispatch(`function() ${devices} end`);
    }

    onConfigChanged: Compositor.dispatch(config)
    onDevicesChanged: applyDevices()

    Process {
        id: list

        command: ["hyprctl", "devices", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const names = (JSON.parse(text).mice ?? []).map(m => m.name).filter(n => /touchpad/i.test(n));
                if (names.join() !== pointer.touchpads.join())
                    pointer.touchpads = names;
            }
        }
    }
}
