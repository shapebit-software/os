# Application Platform

ShapeBit OS needs a solid set of essential apps, a wide selection of third-party software, built-in support for AppImage applications, and a developer-friendly environment.

## Desktop Core

Essential applications are part of the immutable OS image, shared by all users, and updated and rolled back with the OS. 

- **Settings**;
- **Files**;
- **Apps**
- **Diagnostics**;
- **Terminal**
- **Text**

Files provides archive handling, thumbnails, and a constrained quick
preview. Full PDF and image viewers, audio and video players, office suites, scanning applications, and browsers remain user applications.

Process and resource views belong to Diagnostics.

Disk, storage, firmware, device, and printing configuration belong to Settings. 

Screenshot and screen-recording controls belong to the shell.

## User Apps

The normal application UI exposes exactly two Flatpak sources:

- Flathub for third-party applications;
- the ShapeBit repository for applications and integration artifacts authored and maintained by ShapeBit.

The ShapeBit repository may contain ShapeBit binaries. For third-party software never stores, mirrors, or redistributes the third party's binaries.

Additional Flatpak remotes are an advanced per-user
feature.

Recommendations are a manually curated, signed ShapeBit list. No third-party application binary is preinstalled in the OS image.

### Browser choice and integration

First-login onboarding offers these five browsers:

1. Google Chrome;
2. Chromium;
3. Firefox;
4. GNOME Web.

No browser is preselected. An online user may select one browser, which is installed into that user's Flatpak installation and made their default. The step may be skipped, including while offline.

The Chrome integration uses `extra-data` to download Google's official Chrome package directly from Google and wraps it locally as a per-user Flatpak.
The Chromium integration uses an exact, consistent set of Fedora-signed Chromium RPMs, including split runtime packages, downloaded directly from Fedora and wrapped locally.
Firefox, and GNOME Web use their cataloged Flathub packages.

## AppImage model

AppImage is a per-user portable-application path separate from the Flatpak catalog.

Opening an AppImage offers **Run once**, **Add to Apps**, and **Cancel**.

The AppImage manager watches `Downloads`, `Desktop`, and explicitly added directories with filesystem events, identifies the file format rather than trusting its extension, and alerts once for each new content hash. 

## Developer environment

The immutable host contains rootless Podman and Distrobox.

Distrobox is a convenience and compatibility boundary, not a security sandbox.

Initially, the default new container uses the Fedora Toolbox image matching the Fedora major version in the current ShapeBit base.

A dedicated ShapeBit development image is a later product goal.