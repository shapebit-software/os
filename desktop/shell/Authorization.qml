// The polkit agent: when an application asks for an action that needs an
// administrator, such as changing the time zone, the person proves who they
// are with their password (AuthorizationPrompt.qml).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Singleton {
    id: authorization

    // Quickshell does not declare the flow's type to tooling.
    readonly property var flow: agent.flow // qmllint disable unresolved-type
    readonly property bool asking: agent.isActive && flow !== null
    // Whether the last password was wrong; cleared by the next one.
    property bool failed

    function submit(password: string) {
        failed = false;
        flow?.submit(password);
    }

    function cancel() {
        failed = false;
        flow?.cancelAuthenticationRequest();
    }

    PolkitAgent {
        id: agent
    }

    Connections {
        target: authorization.flow
        ignoreUnknownSignals: true

        function onAuthenticationFailed() {
            authorization.failed = true;
        }
    }
}
