// The computer's connections: wired, Wi-Fi, and Bluetooth, each when it has
// them; the Wi-Fi networks and Bluetooth devices that the network panel and
// Settings list (NetworkPanel.qml, ConnectionsPage.qml); and the connection
// agent (session/connection-agent), which joins networks with a password and
// pairs devices, which Quickshell cannot, and asks what NetworkManager and
// BlueZ need, a network's password again or a pairing code, through the
// question dialog (Question.qml).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking

Singleton {
    id: connectivity

    // Wired devices by their kernel names; the others without Wi-Fi are
    // virtual, such as bridges and loopback.
    readonly property var wired: Networking.devices.values
        .filter(d => d.type !== DeviceType.Wifi && /^(en|eth)/.test(d.name))
    readonly property bool wiredConnected: wired.some(d => d.connected)
    readonly property WifiDevice wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property WifiNetwork wifiNetwork: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property string wifiDetail: !Networking.wifiEnabled ? "Off" : wifiNetwork?.name ?? "Not connected"
    // The networks in reach, with names: the one in use first, then those
    // known, then by signal.
    readonly property var networks: [...(wifi?.networks.values ?? [])].filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
    // Untyped, since the Bluetooth module does not declare these types to
    // tooling.
    readonly property var adapter: Bluetooth.defaultAdapter // qmllint disable unresolved-type
    readonly property var bluetoothDevice: adapter?.devices.values.find(d => d.connected) ?? null
    readonly property string bluetoothDetail: !adapter?.enabled ? "Off" : bluetoothDevice?.name ?? "On"
    // The paired devices, connected first, then those nearby that name
    // themselves.
    readonly property var devices: [...(adapter?.devices.values ?? [])].filter(d => d.paired || d.deviceName)
        .sort((a, b) => (b.paired - a.paired) || (b.connected - a.connected) || a.name.localeCompare(b.name))

    // What came of joining networks and pairing devices, by network name or
    // device path: { busy } while it goes on, then { error } if it failed.
    property var joins: ({})
    property var pairs: ({})

    // The agent: the source tree's in development (make run), otherwise the
    // installed one.
    readonly property string agentPath: Quickshell.env("DESKTOP_SHELL")
        ? `${Quickshell.env("DESKTOP_SHELL")}/../session/connection-agent`
        : "/usr/libexec/desktop/connection-agent"
    // The agent's questions that are open, by its ids.
    property var asked: []

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function toggleBluetooth() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }

    // Whether joining the network takes a password: it is secured, and not
    // known, so NetworkManager has none.
    function needsPassword(network: WifiNetwork): bool {
        return !network.known && ![WifiSecurityType.Open, WifiSecurityType.Owe, WifiSecurityType.Unknown]
            .includes(network.security); // qmllint disable unresolved-type
    }

    // Joins a network: with a password through the agent, otherwise as
    // NetworkManager knows it, or open.
    function join(network: WifiNetwork, password: string) {
        if (!password) {
            network.connect();
            return;
        }
        joins = Object.assign({}, joins, { [network.name]: { busy: true } });
        send({ join: network.name, password: password });
    }

    // Pairs a device, then connects it; a paired one connects, or, connected,
    // disconnects.
    function use(device: var) {
        if (device.connected) {
            device.disconnect();
        } else if (device.paired) {
            device.connect();
        } else {
            pairs = Object.assign({}, pairs, { [device.dbusPath]: { busy: true } });
            send({ pair: device.dbusPath });
        }
    }

    // Looks for networks and devices while they are shown.
    function scan(networks: bool, devices: bool) {
        if (wifi)
            wifi.scannerEnabled = networks;
        if (adapter?.enabled && adapter.discovering !== devices)
            adapter.discovering = devices;
    }

    function send(message: var) {
        agent.write(JSON.stringify(message) + "\n");
    }

    function heard(line: string) {
        const message = JSON.parse(line);
        if (message.ask !== undefined) {
            asked = [...asked, message.ask];
            Question.askFor(`agent-${message.ask}`, message, answer => {
                asked = asked.filter(id => id !== message.ask);
                send(Object.assign({ answer: message.ask }, answer));
            });
        } else if (message.cancel !== undefined) {
            asked = asked.filter(id => id !== message.cancel);
            Question.dropped(`agent-${message.cancel}`);
        } else if (message.event) {
            const outcome = message.ok ? {} : { [message.target]: { error: message.reason } };
            if (message.event === "join") {
                const next = Object.assign({}, joins, outcome);
                if (message.ok)
                    delete next[message.target];
                joins = next;
            } else {
                const next = Object.assign({}, pairs, outcome);
                if (message.ok)
                    delete next[message.target];
                pairs = next;
            }
        }
    }

    // It runs as long as the shell; should it end, its questions go, and it
    // starts again.
    Process {
        id: agent

        command: [connectivity.agentPath]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => connectivity.heard(line)
        }
        onRunningChanged: {
            if (running)
                return;
            for (const id of connectivity.asked)
                Question.dropped(`agent-${id}`);
            connectivity.asked = [];
            connectivity.joins = {};
            connectivity.pairs = {};
            restart.start();
        }
    }
    Timer {
        id: restart
        interval: 2000
        onTriggered: agent.running = true
    }
}
