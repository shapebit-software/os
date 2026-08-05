# Installer UI

The Dioxus frontend collects installation choices, submits typed requests from
the shared protocol, and displays progress and errors. It must not execute
privileged operations or pass arbitrary commands to the backend.

The first integration uses a mock backend before any real-disk workflow.
