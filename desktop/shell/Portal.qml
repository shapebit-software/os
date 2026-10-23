// The shell's portals: when an application opens or saves a file, takes a
// screenshot, or shares the screen, the portal backend (session/portal) asks
// over this socket, one JSON line naming the portal, and the shell answers
// on the same connection, one line too: the file chooser (FileChooser.qml),
// the capture overlay (Capture.qml), and the share picker (SharePicker.qml).
// The backend closing the connection, as when the application gives up,
// closes what the question opened.
pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: portal

    // One for each Wayland display, which the backend knows too, so
    // desktops in development, nested in another, keep to their own.
    readonly property string path: `${Quickshell.env("XDG_RUNTIME_DIR")}/desktop/portal-${Quickshell.env("WAYLAND_DISPLAY")}.sock`

    function answer(socket: Socket, answer: var) {
        socket.write(JSON.stringify(answer) + "\n");
        socket.flush();
    }

    function ask(socket: Socket, line: string) {
        const request = JSON.parse(line);
        const handler = { "file-chooser": FileChooser, "screenshot": Capture, "screencast": SharePicker }[request.portal];
        if (handler)
            handler.ask(socket, request);
        else
            answer(socket, {});
    }

    function dropped(socket: Socket) {
        FileChooser.dropped(socket);
        Capture.dropped(socket);
        SharePicker.dropped(socket);
    }

    // The socket's folder, in the runtime directory, before the socket.
    Process {
        command: ["mkdir", "-p", portal.path.substring(0, portal.path.lastIndexOf("/"))]
        running: true
        onRunningChanged: {
            if (!running)
                server.active = true;
        }
    }

    SocketServer {
        id: server

        path: portal.path
        handler: Socket {
            id: socket

            parser: SplitParser {
                onRead: line => portal.ask(socket, line)
            }
            onConnectedChanged: {
                if (!connected)
                    portal.dropped(socket);
            }
        }
    }
}
