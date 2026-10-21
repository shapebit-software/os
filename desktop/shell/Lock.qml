// The lock screen: locking the session, checking the password to unlock it,
// and locking by itself after the computer has been idle (Settings).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland

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

    IdleMonitor {
        enabled: Settings.lockAfter > 0 && !screenLock.locked
        timeout: Settings.lockAfter
        // Not while a video plays, for example.
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle)
                screenLock.lock();
        }
    }
}
