# ADR-0023: Application Platform and System Set

**Status:** Accepted

**Date:** 2026-08-09

**Supersedes:** [ADR-0017](ADR-0017-application-distribution-and-appimage.md)

## Context

ShapeBit OS needs an offline-capable desktop core, a broad independently
updated application catalog, strong attribution for third-party software, and
first-class AppImage and developer workflows. The earlier application ADR left
the exact system set open and limited the ShapeBit Flatpak repository to
first-party applications. Browser integration now also requires a narrow way to
publish ShapeBit-authored packaging instructions without redistributing
third-party binaries.

## Decision

### Immutable desktop core

Components required to operate the desktop are part of the immutable OS image,
shared by all users, and updated and rolled back with the OS. They include the
compositor and shell, greeter and lock surfaces, authorization UI, portals,
first-login UI, and these graphical applications:

- **ShapeBit Settings**;
- **ShapeBit Files**;
- **ShapeBit Apps**, including Flatpak, AppImage, default-application, and
  browser-selection flows;
- **ShapeBit Diagnostics**;
- **ShapeBit Terminal**, hidden from the ordinary launcher until developer mode
  is enabled but available to guided diagnostics;
- **ShapeBit Help** with essential offline documentation;
- **ShapeBit Text**, a plain-text editor with continuous autosave and recovery;
- **ShapeBit Calculator**, with basic and scientific modes and per-user local
  history.

ShapeBit Files provides archive handling, thumbnails, and a constrained quick
preview. Full PDF and image viewers, audio and video players, office suites,
scanning applications, and browsers remain user applications. Process and
resource views belong to Diagnostics. Disk, storage, firmware, device, and
printing configuration belong to Settings. Screenshot and screen-recording
controls belong to the shell. ShapeBit does not add separate system
applications that duplicate those integrated functions.

The host includes the minimal command-line tools needed for filesystems,
networking, boot, Flatpak, systemd, diagnostics, and administration. It does not
include general-purpose compiler toolchains, language SDKs, development headers,
or project-specific build dependencies.

### Flatpak sources and integration artifacts

The normal application UI exposes exactly two Flatpak sources:

- Flathub for third-party applications;
- the ShapeBit repository for applications and integration artifacts authored
  and maintained by ShapeBit.

The ShapeBit repository may contain ShapeBit binaries. For third-party software
it may contain only ShapeBit-authored manifests, scripts, metadata, sandbox
configuration, and other integration instructions. It never stores, mirrors,
or redistributes the third party's binaries. Such an integration uses a
ShapeBit-owned application ID rather than impersonating an existing third-party
Flatpak ID.

Third-party payloads are downloaded at install or update time directly from the
identified upstream producer or an explicitly named trusted distributor using
Flatpak `extra-data`. The integration binds the exact URL, size, and digest and
validates available upstream package signatures during the release process.
ShapeBit does not silently substitute a mirror if the source becomes
unavailable. The UI separately identifies the software author, binary builder
or distributor, and ShapeBit as integration maintainer.

Every integration requires license and branding review. Not hosting the binary
reduces redistribution risk but is not treated as automatic legal permission.
ShapeBit does not remove upstream terms, modify third-party branding to imply
endorsement, or describe an integration as official unless the producer has
approved it.

The full Wayland-compatible Flathub catalog remains searchable. The UI shows
the actual source and whether a Flathub application is publisher-verified or
community-maintained. Additional Flatpak remotes are an advanced per-user
feature available through developer tooling or the CLI and receive no ShapeBit
application guarantee.

Recommendations are a manually curated, signed ShapeBit list. Paid promotion
does not determine inclusion. Detailed review and removal criteria belong to
D04. No third-party application binary is preinstalled in the OS image.

### Browser choice and integration

First-login onboarding offers these five browsers:

1. Google Chrome;
2. Chromium;
3. Firefox;
4. Brave;
5. GNOME Web.

No browser is preselected. An online user may select one browser, which is
installed into that user's Flatpak installation and made their default. The UI
shows publisher, binary source, license, verification or integration status,
and download size before installation. The step may be skipped, including
while offline. Other browsers may be installed later and the user may keep
several and change the default.

The ShapeBit Chrome integration uses `extra-data` to download Google's official
Chrome package directly from Google and wraps it locally as a per-user Flatpak.
The ShapeBit Chromium integration uses an exact, consistent set of Fedora-signed
Chromium RPMs, including split runtime packages, downloaded directly from
Fedora and wrapped locally. Chromium therefore uses upstream Chromium code with
binaries built and signed by Fedora; it is not described as an upstream binary
release. Firefox, Brave, and GNOME Web use their cataloged Flathub packages.

Chrome and Chromium integration updates are generated after the upstream
package changes, signature and digest validation succeeds, and ShapeBit's
integration tests pass. Installation and updates prepare a new Flatpak
deployment without damaging the active one. A running browser finishes on its
old deployment and the UI requests a restart, especially for a security update.

### Per-user Flatpak lifecycle

- Every user has an independent Flatpak installation inside their encrypted
  home.
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
and per user. ShapeBit provides no automatic Flatpak application rollback;
pre-acceptance OS rollback does not change Flatpak versions or application
data.

### Wayland-only application scope

The initial desktop supports native Wayland applications only and does not
include XWayland. The normal application UI hides Flatpaks that declare only X11
support. If an installed update would remove Wayland support, the updater keeps
the working version and does not activate the incompatible update. Developer
tooling may expose the unsupported catalog.

### AppImage model

AppImage is a per-user portable-application path separate from the Flatpak
catalog. ShapeBit does not operate an AppImage repository, classify AppImages
as verified or unverified, maintain a publisher-key registry, or sandbox them.
Before execution or import, the UI warns that an AppImage receives all
permissions of the active user, including the unlocked home, session
interfaces, network, and accessible devices, but receives neither root
automatically nor access to another inactive home.

Opening an AppImage offers **Run once**, **Add to Apps**, and **Cancel**. Import
copies it into a managed per-user directory and adds launcher integration. The
manager reads metadata without executing payload code, records a content hash,
and provides removal and update actions. If embedded update information is
usable, it downloads a replacement beside the current file and requires
confirmation before atomic replacement. An internal self-updater remains
outside ShapeBit's control.

The manager watches `Downloads`, `Desktop`, and explicitly added directories
with filesystem events, identifies the file format rather than trusting its
extension, and alerts once for each new content hash. It does not scan the full
home or removable media automatically. ShapeBit adds no AppImage-specific
restriction around handlers, autostart, user services, or other ordinary
unsandboxed desktop integration. X11-only AppImages remain unsupported.

### Developer environment

The immutable host contains rootless Podman and Distrobox. Distrobox replaces
Toolbox as the supported interactive development environment. Compiler
toolchains, SDKs, language runtimes, headers, and project dependencies belong
inside containers rather than on the host.

Distrobox is a convenience and compatibility boundary, not a security sandbox.
Its normal integration exposes the user's home and selected session, display,
audio, and device interfaces. Developer documentation must not recommend it for
untrusted code isolation.

Initially, the default new container uses the Fedora Toolbox image matching the
Fedora major version in the current ShapeBit base. The source is Fedora's
official registry and the resolved digest is recorded at creation. Existing
containers survive an OS update and are not silently rebuilt; their user
updates packages with Distrobox. New containers follow the new ShapeBit base.
Developer mode may select other compatible OCI images, which are identified as
external and receive no ShapeBit compatibility guarantee.

A dedicated ShapeBit development image is a later product goal. It becomes the
first default only after it is built, versioned, and validated as a supported
environment. The matching Fedora image remains a supported reference and
fallback.

## Consequences

- Essential desktop operation and basic text and calculation work remain
  available offline.
- Complex document and media parsers update independently as sandboxed user
  applications rather than enlarging the host image.
- Per-user Flatpak installations may duplicate runtimes across encrypted homes.
- ShapeBit can integrate upstream proprietary or distributor-built packages
  without hosting their binaries, but assumes maintenance, testing, metadata,
  and legal-review responsibilities for its wrapper.
- Chrome uses Google-built binaries; Chromium uses Fedora-built binaries. The
  UI preserves that distinction.
- AppImage retains broad native compatibility and broad user-level authority.
- Distrobox keeps development dependencies away from the immutable host but
  does not protect the home from code running inside a developer container.

## Boundaries

This ADR owns the system application and command-line set, application sources,
third-party integration artifacts, browser onboarding, per-user Flatpak
lifecycle, Wayland catalog scope, AppImage behavior, and the Podman/Distrobox
developer environment. ADR-0011 and ADR-0016 own encrypted-home and capacity
boundaries. ADR-0018 owns developer-mode presentation and authorization.
ADR-0020 owns media privacy and notification behavior. ADR-0024 owns
recommendation governance. ADR-0042 owns ShapeBit production signing roles and
does not convert Flathub, upstream package, or AppImage keys into ShapeBit trust
delegations.

## Open questions

- Whether and when XWayland becomes a supported compatibility layer.

## Related decisions

- [ADR-0002](ADR-0002-filesystem-ownership.md)
- [ADR-0040](ADR-0040-forward-only-migrations-and-trial-bounded-rollback.md)
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0016](ADR-0016-initial-installation-and-storage-profile.md)
- [ADR-0018](ADR-0018-desktop-session-and-authorization.md)
- [ADR-0020](ADR-0020-media-privacy-and-notifications.md)
- [ADR-0024](ADR-0024-application-recommendations.md)
- [ADR-0042](ADR-0042-production-signing-operations.md)

## References

- [Flatpak extra-data sources](https://docs.flatpak.org/en/latest/module-sources.html#extra-data)
- [Flathub application verification](https://docs.flathub.org/docs/for-users/verification)
- [Google Chrome Flathub manifest](https://github.com/flathub/com.google.Chrome/blob/master/com.google.Chrome.yaml)
- [Fedora Chromium package](https://packages.fedoraproject.org/pkgs/chromium/chromium/)
- [Distrobox overview](https://distrobox.it/)
- [Distrobox compatibility](https://distrobox.it/compatibility/)
- [AppImage desktop integration](https://docs.appimage.org/reference/desktop-integration.html)
- [AppImage update information](https://docs.appimage.org/packaging-guide/optional/updates.html)
