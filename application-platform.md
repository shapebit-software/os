# Application Platform

System applications, Flatpak, AppImage, Distrobox, application ownership, permissions, updates, and recommendations.

These pages are living architecture, not implementation evidence. Unlabeled
sections describe the current design. A **Proposed** label marks a section that
still requires explicit review and validation; remove the label once that review
is complete.

Changing a current rule requires updating its owning section and every affected
cross-area contract.

## Application model

### Application Platform and System Set



#### Purpose and constraints

ShapeBit OS needs an offline-capable desktop core, a broad independently
updated application catalog, strong attribution for third-party software, and
first-class AppImage and developer workflows. The earlier application architecture section left
the exact system set open and limited the ShapeBit Flatpak repository to
first-party applications. Browser integration now also requires a narrow way to
publish ShapeBit-authored packaging instructions without redistributing
third-party binaries.

#### Design

##### Immutable desktop core

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

##### Flatpak sources and integration artifacts

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

##### Browser choice and integration

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

##### Per-user Flatpak lifecycle

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

##### Wayland-only application scope

The initial desktop supports native Wayland applications only and does not
include XWayland. The normal application UI hides Flatpaks that declare only X11
support. If an installed update would remove Wayland support, the updater keeps
the working version and does not activate the incompatible update. Developer
tooling may expose the unsupported catalog.

##### AppImage model

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

##### Developer environment

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

#### Tradeoffs

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

#### Ownership boundaries

This section owns the system application and command-line set, application sources,
third-party integration artifacts, browser onboarding, per-user Flatpak
lifecycle, Wayland catalog scope, AppImage behavior, and the Podman/Distrobox
developer environment. [Per-User Encrypted Homes](security-identity.md) and [Initial Installation and Storage Profile](base-system.md) own encrypted-home and capacity
boundaries. [Desktop Session and Authorization Boundaries](desktop.md) owns developer-mode presentation and authorization.
[Media, Privacy, and Notification Policy](desktop.md) owns media privacy and notification behavior. [Application Recommendations](application-platform.md) owns
recommendation governance. [Production Signing Operations](boot-system-lifecycle.md) owns ShapeBit production signing roles and
does not convert Flathub, upstream package, or AppImage keys into ShapeBit trust
delegations.

#### Open questions

- Whether and when XWayland becomes a supported compatibility layer.

## Discovery and recommendations

### Application Recommendations


#### Purpose and constraints

The ShapeBit application UI exposes the full supported catalog while also
offering a much smaller curated recommendation list. A recommendation is a
stronger product signal than catalog availability, but the project is currently
managed by one person and must not invent a multi-person approval process that
does not exist.

#### Design

##### Authority and change record

The ShapeBit project owner is the sole curator and approver of the
recommendation list. No vote, second reviewer, or external approval is required.
Every addition, removal, ordering change, or category change has a short public
rationale in the repository history.

Automation may identify maintenance, permissions, ownership, availability,
license, or security changes and present a report. It never changes the list or
approves a recommendation. The approval model may be replaced only after the
project actually has a team and an explicit architecture update defines its authority.

##### Inclusion criteria

A recommended application must:

- run natively on the supported Wayland-only ShapeBit desktop;
- come from Flathub or an integration accepted under [Application Platform and System Set](application-platform.md);
- identify the software author, package maintainer, and binary source
  accurately;
- be actively maintained and have a credible path for security fixes;
- request permissions proportionate to its advertised function;
- pass installation, launch, update, and removal checks on the current stable
  ShapeBit release;
- have no unresolved license or branding issue known to ShapeBit; and
- provide clear user value, even when a competing application is also listed.

Flathub publisher verification is not mandatory. A community-maintained package
may be recommended when its community status and actual source remain visible.
Paid promotion does not determine inclusion.

##### Re-review

There is no calendar-based re-review interval, expiry date, or automatic stale
status. The curator initiates a review at their discretion or in response to a
specific signal. Relevant signals include project abandonment or transfer,
loss of Wayland support, a material permission expansion, a security incident,
source disappearance, and a license or business-model change.

Automation may report these signals but does not interpret silence or elapsed
time as a removal decision.

##### Removal

Removal from recommendations requires the curator's decision and a short public
rationale. It removes only the recommendation signal. ShapeBit does not
automatically uninstall the application or delete its data, and an existing
installation continues to receive updates from its configured source.

When the reason is a serious known security risk, ShapeBit may warn users who
have the application installed. Blocking execution, revoking a package, or
forcing removal is outside the recommendation mechanism and requires a separate
security authority and decision.

##### Signed manifest and presentation

Recommendations are distributed as a small signed manifest independently of
the OS image. It records at least the application ID, source, category, manual
position, attribution and verification information, license, and short
rationale. Exact serialization and production key operations belong to the
release-manifest and signing work in D21-D23.

The system automatically retrieves a newer manifest. A valid signed manifest
atomically replaces the current one. Download, parsing, or signature failure
keeps the last valid manifest; ShapeBit never falls back to unsigned data. The
OS image contains an initial signed copy so the recommendation view works before
its first refresh. Updating this manifest neither installs nor removes an
application.

There is one canonical list for all users. The curator manually defines
categories and ordering. ShapeBit does not personalize recommendations from
telemetry, launch history, country, or account profile. Flathub popularity or
ratings may be displayed as external information but do not reorder the list.
Installed applications remain visible with an installed marker. The complete
catalog remains searchable, and there is no fixed maximum list length.

#### Tradeoffs

- Governance matches the project's actual one-person maintenance model.
- Every recommendation remains an explicit human decision with a public reason.
- The absence of a mandatory review interval reduces process overhead but can
  leave a stale recommendation until the curator or automation notices a
  relevant change.
- A signed independently refreshed list permits fast recommendation removal
  without an OS release.
- Recommendation removal is not confused with remote application control.

#### Ownership boundaries

This section owns recommendation authority, inclusion, re-review, removal,
distribution behavior, ordering, and personalization. [Application Platform and System Set](application-platform.md) owns application
sources, installation, updates, permissions, and runtime support. D21-D23 own
the manifest serialization and production signing system. A future application
revocation policy is separate from recommendations.
