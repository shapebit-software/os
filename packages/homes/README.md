# Homes

Each person's encrypted home, with systemd-homed: the package `shapebit-homes`.

Users are [systemd-homed](https://systemd.io/HOME_DIRECTORY/) homes. Each home
is a LUKS2-encrypted image, `/home/<user>.home` in `@people`, with Btrfs
inside, unlocked by its owner's password at login. The installer creates the
first owner, an administrator (`wheel`), directly on the installed disk.
systemd-homework leaves that Btrfs without SELinux labels, which keeps the
login screen out of the home; homed mounts it with `defcontext=` so it reads
as a home directory
([selinux-labels.conf](selinux-labels.conf)).

## Storage

The computer keeps a **reserve** that homes can't take, so it always has room
for logs, recovery, and staging an update; its size is in
[disks.h](../installer/backend/disks.h). Today only the installer applies it,
by sizing the first owner's home; later homes take systemd-homed's default.

**Planned:** homes share one pool instead of fixed sizes. Each is guaranteed
a minimum, can burst beyond it into shared space, and can be capped by its
owner; a new home is created only if its minimum fits without taking space
from another home or the reserve. The computer warns when free space is
**low** (below 16 GiB or 10% of the pool, whichever is larger) and
**critical** (below 8 GiB), and reports **exhausted** when no burst space is
left.
