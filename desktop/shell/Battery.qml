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

    // The bolt drawn inside the icon while charging, on a grid 6 wide and 10
    // high.
    readonly property string bolt: "M3.8.4.6 5.6H3l-.8 4 3.2-5.2H3z"

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
