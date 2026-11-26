// Exercise the actual Settings component without a compositor or a session bus.
import QtQuick
import Quickshell
import qs.settings

ShellRoot {
    FloatingWindow {
        visible: true
        implicitWidth: 760
        implicitHeight: 800

        LicensesPage {
            id: licenses
            width: 700
            Component.onCompleted: visible = false
            onBodyChanged: {
                if (body.includes("GNU GENERAL PUBLIC LICENSE")) {
                    console.warn("LICENSE_VIEWER_OK");
                    Qt.quit();
                }
            }
        }
        Timer {
            interval: 100
            running: true
            onTriggered: licenses.visible = true
        }
        Timer {
            interval: 100
            running: true
            repeat: true
            onTriggered: {
                if (licenses.components.length && !licenses.selected) {
                    licenses.opened = licenses.components.find(c => c.name === "shapebit");
                    licenses.open("shapebit/LICENSE-GPL-3.0-or-later.txt");
                }
            }
        }
        Timer {
            interval: 15000
            running: true
            onTriggered: {
                console.error("LICENSE_VIEWER_FAILED", licenses.problem);
                Qt.exit(1);
            }
        }
    }
}
