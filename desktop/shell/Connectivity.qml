// The computer's connections: wired, Wi-Fi, and Bluetooth, each when it has
// them.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking

Singleton {
    // Wired devices by their kernel names; the others without Wi-Fi are
    // virtual, such as bridges and loopback.
    readonly property var wired: Networking.devices.values
        .filter(d => d.type !== DeviceType.Wifi && /^(en|eth)/.test(d.name))
    readonly property bool wiredConnected: wired.some(d => d.connected)
    readonly property WifiDevice wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property WifiNetwork wifiNetwork: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property string wifiDetail: !Networking.wifiEnabled ? "Off" : wifiNetwork?.name ?? "Not connected"
    // Untyped, since the Bluetooth module does not declare these types to
    // tooling.
    readonly property var adapter: Bluetooth.defaultAdapter // qmllint disable unresolved-type
    readonly property var bluetoothDevice: adapter?.devices.values.find(d => d.connected) ?? null
    readonly property string bluetoothDetail: !adapter?.enabled ? "Off" : bluetoothDevice?.name ?? "On"

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function toggleBluetooth() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }
}
