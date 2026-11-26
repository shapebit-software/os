"""dbusmock's UPower template, with the display device's properties that
Quickshell's UPower reads, such as PowerSupply, which makes a battery the
computer's own (../README.md)."""

from dbusmock import mockobject
from dbusmock.templates import upower as upstream

# dbusmock takes a template's methods from its module's names: upstream's,
# then those below over them.
globals().update({name: value for name, value in vars(upstream).items() if not name.startswith("_")})


def load(mock, parameters):
    upstream.load(mock, parameters)
    mockobject.objects[mock.p_display_dev].AddProperties(
        upstream.DEVICE_IFACE, {"PowerSupply": True, "Capacity": 100.0, "NativePath": "", "Model": ""})
