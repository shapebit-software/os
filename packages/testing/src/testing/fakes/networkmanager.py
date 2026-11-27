"""dbusmock's NetworkManager template, with GetAllDevices, which Quickshell's
Networking lists the devices with (development/simulator/README.md)."""

from dbusmock import mockobject
from dbusmock.templates import networkmanager as upstream

# dbusmock takes a template's methods from its module's names: upstream's,
# then those below over them.
globals().update({name: value for name, value in vars(upstream).items() if not name.startswith("_")})


def load(mock, parameters):
    upstream.load(mock, parameters)
    mockobject.objects[upstream.MANAGER_OBJ].AddMethod(
        upstream.MANAGER_IFACE, "GetAllDevices", "", "ao", f"ret = self.Get('{upstream.MANAGER_IFACE}', 'Devices')")
