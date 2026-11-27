"""dbusmock's power profiles template, with ActiveProfileHolds of the type
that power-profiles-daemon gives it, aa{sv}, which Quickshell's
PowerProfiles reads (development/simulator/README.md)."""

import dbus
from dbusmock.templates import upower_power_profiles_daemon as upstream

# dbusmock takes a template's methods from its module's names: upstream's,
# then those below over them.
globals().update({name: value for name, value in vars(upstream).items() if not name.startswith("_")})


def load(mock, parameters):
    upstream.load(mock, parameters)
    mock.props[upstream.MAIN_IFACE]["ActiveProfileHolds"] = dbus.Array([], signature="a{sv}")
