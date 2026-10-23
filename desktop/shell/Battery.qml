// The laptop's battery, through UPower: its charge, whether it charges, and
// the time left; and the power profile, through power-profiles-daemon.
// Computers without a battery have none.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: battery

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool available: (device?.ready ?? false) && device.isLaptopBattery && device.isPresent
    // From 0 to 100.
    readonly property int percent: Math.round((device?.percentage ?? 0) * 100)
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
        || device?.state === UPowerDeviceState.PendingCharge
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
    readonly property bool low: percent <= 10 && !charging && !full
    // As the tooltip says it, such as "2 h 15 min left".
    readonly property string timeText: full ? "Fully charged"
        : charging ? ((device?.timeToFull ?? 0) > 0 ? `${duration(device.timeToFull)} until full` : "Charging")
        : (device?.timeToEmpty ?? 0) > 0 ? `${duration(device.timeToEmpty)} left` : ""

    // The icon: the outline and its tip; the charge as a bar inside, or a
    // bolt while charging.
    readonly property string outline: "M2.2 4.6h9.6a1 1 0 0 1 1 1v4.8a1 1 0 0 1-1 1H2.2a1 1 0 0 1-1-1V5.6a1 1 0 0 1 1-1zM14.4 6.6v2.8"
    readonly property string level: charging ? "" : `M2.8 6.2h${(8.4 * Math.max(0.08, percent / 100)).toFixed(2)}v3.6H2.8z`
    readonly property string bolt: charging ? "M7.6 5.2 5.4 8.4h2.1l-.7 2.4 2.5-3.3H7.1z" : ""

    // The profiles that this computer offers, in order.
    readonly property var profiles: [
        { profile: PowerProfile.PowerSaver, name: "Power Saver", detail: "Longer battery life" },
        { profile: PowerProfile.Balanced, name: "Balanced", detail: "Speed and battery life" },
        ...PowerProfiles.hasPerformanceProfile
            ? [{ profile: PowerProfile.Performance, name: "Performance", detail: "Fastest, uses more power" }] : [],
    ]
    readonly property int profile: PowerProfiles.profile

    function setProfile(profile: int) {
        PowerProfiles.profile = profile;
    }

    function duration(seconds: real): string {
        const minutes = Math.round(seconds / 60);
        const hours = Math.floor(minutes / 60);
        return hours ? `${hours} h ${minutes % 60} min` : `${minutes} min`;
    }
}
