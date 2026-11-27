// The shell's portals: when an application opens or saves a file, takes a
// screenshot, shares the screen, or asks the person something, such as for
// a permission, the portal backend (portal/src/portal) asks over this socket,
// one JSON line naming the portal, and the shell answers on the same
// connection, one line too: the file chooser (FileChooser.qml), the
// questions (Question.qml), and what features answer, such as capture's
// screenshots and screen sharing (Features.portals).
// The backend closing the connection, as when the application gives up,
// closes what the question opened.
pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: portal

    // One for each Wayland display, which the backend knows too.
    readonly property string path: `${Quickshell.env("XDG_RUNTIME_DIR")}/desktop/portal-${Quickshell.env("WAYLAND_DISPLAY")}.sock`

    function answer(socket: Socket, answer: var) {
        socket.write(JSON.stringify(answer) + "\n");
        socket.flush();
    }

    function ask(socket: Socket, line: string) {
        const request = JSON.parse(line);
        const handler = handlers()[request.portal];
        if (handler)
            handler.ask(socket, request);
        else
            answer(socket, {});
    }

    function dropped(socket: Socket) {
        for (const handler of Object.values(handlers()))
            handler.dropped(socket);
    }

    // What answers each portal: the shell's own, then features'.
    function handlers(): var {
        return Object.assign({ "file-chooser": FileChooser, "question": Question }, Features.portals);
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
