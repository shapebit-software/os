"""dbusmock's BlueZ template, whose adapters have a discovery filter, without
which their StartDiscovery fails (../README.md)."""

import dbus
from dbusmock import mockobject
from dbusmock.templates import bluez5 as upstream

# dbusmock takes a template's methods from its module's names: upstream's,
# then those below over them.
globals().update({name: value for name, value in vars(upstream).items() if not name.startswith("_")})


@dbus.service.method(upstream.BLUEZ_MOCK_IFACE, in_signature="ss", out_signature="s")
def AddAdapter(self, device_name, system_name):
    path = upstream.AddAdapter(self, device_name, system_name)
    mockobject.objects[path].props[upstream.ADAPTER_IFACE]["DiscoveryFilter"] = dbus.Dictionary({}, signature="sv")
    return path
