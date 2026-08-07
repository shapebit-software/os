# ADR-0017: Application Distribution and AppImage Integration

**Status:** Accepted
**Date:** 2026-08-07

## Context

ShapeBit OS needs a broad application catalog without allowing applications to
modify the immutable host. It also needs first-class support for portable
AppImage files, whose trust, update, and isolation model differs fundamentally
from a repository-managed Flatpak.

## Decision

### System applications

Components required to operate the desktop are part of the immutable OS image
and are shared by all users. This includes the compositor and shell, login and
lock surfaces, ShapeBit settings and application-management UI, portals, and
minimal diagnostics. The exact inclusion of other essential tools remains open.

System applications update and roll back with the OS. General-purpose user
applications, including browsers, media applications, communications tools, and
office software, are not added to the host image.

### Flatpak sources and ownership

The normal application UI exposes exactly two Flatpak sources:

- Flathub for all third-party applications;
- the ShapeBit repository for applications authored or formally owned by
  ShapeBit.

ShapeBit does not mirror Flathub or silently rebuild third-party applications
under their existing App IDs. The UI always shows the actual source and whether
a Flathub application is publisher-verified or community-maintained. The full
Wayland-compatible Flathub catalog remains searchable.

Additional Flatpak remotes are an advanced per-user feature available through
developer tooling or the CLI. Their applications are identified as external
sources and receive no ShapeBit quality, availability, or security guarantee.
Adding one does not change support status for the operating system itself.

Recommendations are a manually curated, signed ShapeBit list. ShapeBit may
choose any application from its repository or Flathub, including community-
maintained applications, while preserving the accurate source label. Paid
promotion does not determine recommendations. No Flathub application is
preinstalled in the OS image. First-login onboarding may offer the recommended
set for the user to select and download; offline account creation remains fully
usable with the system applications.

### Per-user Flatpak lifecycle

- Every user has an independent Flatpak installation inside that user's
  encrypted home.
- Applications, runtimes, caches, and application data consume that user's home
  capacity and cannot consume another user's guaranteed minimum.
- Application updates run only while that user's home is active.
- Download staging may use bounded system transaction space, but activation
  first proves that the user's home has sufficient capacity.
- Old application versions, unused runtimes, and explicitly reproducible caches
  may be removed automatically; application data may not.
- Removing a user removes that user's application installation with the home.

Updates that do not add static permissions install automatically. An update
that expands static permissions is downloaded but not activated until the user
approves a human-readable permission diff. Portal permissions remain contextual
and per user. ShapeBit provides no automatic Flatpak application rollback; OS
rollback does not change Flatpak versions or application data.

### Wayland-only application scope

The initial ShapeBit desktop supports native Wayland applications only and does
not include XWayland. The normal application UI hides Flatpaks that declare only
X11 support and shows Wayland-capable applications without an additional
compatibility badge. Developer tooling may expose the hidden catalog.

If an installed Flatpak update would remove Wayland support and become X11-only,
the updater retains the working version and does not activate the incompatible
update. XWayland remains deferred rather than an initial product requirement.

### AppImage model

AppImage is a per-user portable application path alongside, but not inside, the
Flatpak catalog. ShapeBit does not operate an AppImage repository or mix
downloaded AppImages into Flathub search results.

Every AppImage is treated uniformly as an external native executable. ShapeBit
does not classify AppImages as verified or unverified, does not maintain a
publisher-key registry, and does not sandbox them. Before running or importing
one, the UI warns that it receives all permissions of the active user and may
read or modify the entire unlocked home, session interfaces, network, and
accessible devices. It receives neither root automatically nor access to an
inactive user's encrypted home.

Opening an AppImage offers:

- **Run once**, which executes it from its current location without integration;
- **Add to Apps**, which imports it into a managed directory in the user's home
  and adds it to the launcher;
- **Cancel**.

The manager extracts metadata without executing payload code, records a content
hash for change detection, and provides removal and update actions. It does not
display or enforce embedded signature status. If supported update information
exists, the manager downloads a replacement alongside the current file and
requires user confirmation for every update before an atomic replacement. A
self-updater inside an unsandboxed AppImage is outside ShapeBit's control.

The per-user manager watches `Downloads` and `Desktop` plus directories the user
adds explicitly. It uses filesystem events rather than repeatedly scanning the
whole tree, recognizes the file format rather than trusting only the extension,
and alerts once per new content hash with **Run once**, **Add to Apps**, and
**Ignore**. It does not scan the complete home or removable media automatically.

X11-only AppImages are unsupported by the initial Wayland-only desktop. ShapeBit
does not disable an application's internal security mechanisms to make it run.

## Consequences

- Flatpak provides the supported sandboxed application path with broad Flathub
  availability and independently encrypted per-user ownership.
- Essential desktop operation remains available offline from the immutable
  image.
- Per-user installations may duplicate Flatpak runtimes across encrypted homes.
- Permission-expanding and Wayland-regressing updates can leave an older
  application version awaiting user action or an upstream fix.
- AppImage provides broad native compatibility but carries the same risk as any
  downloaded executable with full user permissions.
- AppImage updates, identity, and background behavior cannot receive the same
  guarantees as repository-managed Flatpaks.

## Open questions

- Exact set of system applications included in the OS image.
- AppImage MIME and URL-handler registration, default-application behavior, and
  autostart integration.
- Detailed recommendation-review and removal criteria.
- Whether and when XWayland becomes a supported compatibility layer.

## Related decisions

- [ADR-0002](ADR-0002-filesystem-ownership.md) defines host and user ownership.
- [ADR-0004](ADR-0004-data-migrations-and-rollback.md) defines preserved and
  disposable host state.
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md) defines home activation and
  encryption.
- [ADR-0016](ADR-0016-initial-installation-and-storage-profile.md) defines
  per-user capacity guarantees.

## References

- [Flathub application verification](https://docs.flathub.org/docs/for-users/verification)
- [Flatpak portal integration](https://docs.flatpak.org/en/latest/portals.html)
- [Flatpak command and permission reference](https://docs.flatpak.org/en/latest/flatpak-command-reference.html)
- [AppImage desktop integration](https://docs.appimage.org/reference/desktop-integration.html)
- [AppImage update information](https://docs.appimage.org/packaging-guide/optional/updates.html)
