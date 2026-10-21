// Screenshots and screen recordings: of an area the person draws, a window
// they pick, or a whole screen. Screenshots go to Pictures/Screenshots,
// recordings to Videos/Recordings.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: capture

    readonly property bool recording: recorder.running
    property date startedAt
    // The recording's length so far, as m:ss.
    property string elapsed: "0:00"
    // Whether the area being picked is for a recording.
    property bool pending

    // Picks the area for `mode` ("Area", "Window", or "Screen"), then takes a
    // screenshot or starts recording.
    function start(mode: string, record: bool, screen: ShellScreen) {
        pending = record;
        if (mode === "Screen") {
            run(`${screen.x},${screen.y} ${screen.width}x${screen.height}`);
            return;
        }
        // For a window, slurp offers the windows' boxes from its input.
        picker.boxes = mode === "Window" ? windowBoxes() : "";
        picker.stdinEnabled = mode === "Window";
        picker.command = mode === "Window" ? ["slurp", "-r"] : ["slurp"];
        picker.running = true;
    }

    function stop() {
        recorder.signal(2); // SIGINT: wf-recorder finishes the file.
    }

    // The windows on visible workspaces, as slurp's boxes.
    function windowBoxes(): string {
        return Hyprland.toplevels.values
            .filter(t => t.workspace?.active && t.lastIpcObject.at)
            .map(t => {
                const ipc = t.lastIpcObject;
                return `${ipc.at[0]},${ipc.at[1]} ${ipc.size[0]}x${ipc.size[1]}\n`;
            })
            .join("");
    }

    function run(geometry: string) {
        if (pending) {
            recorder.command = ["sh", "-c", `dir="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")/Recordings"
                mkdir -p "$dir" && exec wf-recorder -g "$1" -f "$dir/Recording $(date '+%F %H-%M-%S').mp4"`, "sh", geometry];
            startedAt = new Date();
            elapsed = "0:00";
            recorder.running = true;
        } else {
            Quickshell.execDetached(["sh", "-c", `dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
                mkdir -p "$dir" && exec grim -g "$1" "$dir/Screenshot $(date '+%F %H-%M-%S').png"`, "sh", geometry]);
        }
    }

    // slurp prints the picked area; Escape prints nothing.
    Process {
        id: picker

        property string boxes

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    capture.run(text.trim());
            }
        }
        onStarted: {
            if (stdinEnabled) {
                write(boxes);
                stdinEnabled = false;
            }
        }
    }

    Process {
        id: recorder
    }

    Timer {
        running: capture.recording
        interval: 1000
        repeat: true
        onTriggered: {
            const seconds = Math.floor((Date.now() - capture.startedAt) / 1000);
            capture.elapsed = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
        }
    }
}
