// The brightness of the built-in display, through brightnessctl, which sets
// it without administrator rights through logind. Computers without a
// backlight, such as most desktops, have none. The brightness keys change it
// in the compositor; the panel reads it again when it opens.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: brightness

    // The backlight, such as "intel_backlight", or none.
    property string device
    readonly property bool available: device !== ""
    // From 0 to 1.
    property real value
    // A sun, for the button and the panel.
    readonly property string icon: "M5.4 8a2.6 2.6 0 1 0 5.2 0a2.6 2.6 0 1 0-5.2 0zM8 1.6v1.5M8 12.9v1.5M1.6 8h1.5M12.9 8h1.5"
        + "M3.5 3.5l1.1 1.1M11.4 11.4l1.1 1.1M3.5 12.5l1.1-1.1M11.4 4.6l1.1-1.1"

    function refresh() {
        reader.running = true;
    }

    function set(value: real) {
        // Never fully dark: the screen would look off.
        const percent = Math.max(1, Math.round(value * 100));
        brightness.value = percent / 100;
        Quickshell.execDetached(["brightnessctl", "--class=backlight", "--device=" + device, "--quiet", "set", percent + "%"]);
    }

    // brightnessctl --machine-readable prints "device,class,current,percent,max".
    Process {
        id: reader

        command: ["brightnessctl", "--class=backlight", "--machine-readable"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.split("\n")[0].split(",");
                brightness.device = fields.length === 5 ? fields[0] : "";
                if (brightness.available)
                    brightness.value = parseInt(fields[3]) / 100;
            }
        }
    }
}
