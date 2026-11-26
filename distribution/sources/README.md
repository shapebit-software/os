# Sources

The source RPMs published with each build ([sources.py](sources.py)), so that
people get what the licenses of its software promise. [release.py](../release.py)
publishes them as OCI artifacts beside the image and the installer.

Sources are collected while the image is built, when Fedora's repositories
still match it, and published before or with it, for as long as that version
can be downloaded: the source RPM of every installed package that has one,
regardless of its license label, as the OCI artifact `<version>-sources`,
which the image label `software.shapebit.sources` names. ShapeBit hosts
copies rather than pointing to Fedora's, as the GPL asks of anyone who
distributes binaries, and COPR deletes old builds. The installer medium's sources are those of everything
on it: the installer's, and those of the system it carries, since a medium
stays on the download site long after `prune` has deleted that system's
version from GHCR. ShapeBit's own packages
are left out: their sources are this repository at the image's revision.
