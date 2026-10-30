// The lock screen: locking the session and checking the password to unlock
// it. hypridle locks it when the computer is idle or goes to sleep (Idle.qml).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.lock

Singleton {
    id: screenLock

    // Kept here: the session lock does not report changes to its own state.
    property bool locked
    // What the system says while unlocking, such as a wrong password or a
    // request for a fingerprint, and whether it is an error.
    property string message
    property bool messageIsError
    readonly property bool checking: pam.active
    property string password

    function lock() {
        message = "";
        locked = true;
    }

    function unlock(password: string) {
        if (pam.active)
            return;
        screenLock.password = password;
        message = "";
        pam.start();
    }

    // The compositor keeps every screen covered until the shell unlocks.
    WlSessionLock {
        id: session

        locked: screenLock.locked

        WlSessionLockSurface {
            color: "black"

            LockSurface {
                anchors.fill: parent
            }
        }
    }

    PamContext {
        id: pam

        config: "login"
        onPamMessage: {
            if (responseRequired) {
                respond(screenLock.password);
                screenLock.password = "";
            } else {
                screenLock.message = message;
                screenLock.messageIsError = messageIsError;
            }
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                screenLock.locked = false;
            } else {
                screenLock.message = "Wrong password";
                screenLock.messageIsError = true;
            }
        }
        onError: error => {
            screenLock.message = "Could not check the password";
            screenLock.messageIsError = true;
        }
    }

    // qs ipc call lock lock; qs ipc call lock isLocked
    IpcHandler {
        target: "lock"

        function isLocked(): bool {
            return screenLock.locked;
        }

        function lock(): void {
            screenLock.lock();
        }
    }
}
