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
