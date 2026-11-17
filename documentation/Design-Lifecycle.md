# System Lifecycle

How ShapeBit is signed, how it boots with trust, how a release is made and
reaches computers, and how a bad release is undone.

## Signing

Development and release builds belong to separate trust domains. A key is
chosen when an image is built, and promotion never re-signs, so a
development build can never become a release.

| Key | Signs | Trusted by |
|---|---|---|
| Development | Local builds, and the checks of every push and pull request (a throwaway key each time) | Only the developer's own machines |
| Release | Every candidate, so every release | Every installed computer |

Each is a pair of keys: one signs the boot loader and the UKI, the other the
TPM values that unlock the disk ([Signing Keys](Design-Security.md#signing-keys)).
The release keys are protected CI secrets, on the runner only while the jobs
that build a candidate or an installer sign. Whoever can approve a release can
ship code to every computer, so the safety of the approver's account matters as
much as the keys'.

> **Goal, not built:** a production key hierarchy, with an offline root that
> only delegates to release, boot and PCR, and repository signing keys, all
> in hardware-backed storage that no CI runner reaches.

## Boot Trust

A computer boots through an unbroken chain of signatures, keeping the
manufacturer's own Secure Boot keys. Today the chain starts with Fedora's
shim, which Microsoft signed:

```text
UEFI Secure Boot
  → Fedora's shim (signed by Microsoft)
  → systemd-boot, signed by ShapeBit
  → the UKI, signed by ShapeBit
  → the sealed system
```

Fedora's shim trusts ShapeBit's key only after a person accepts it, once per
computer, at the first boot of the installer
([Installing ShapeBit](Install.md)).

- The UKI bundles the kernel, the initramfs, the kernel command line, and the
  TPM policy in one signed file; there is no unsigned kernel on the EFI
  System Partition.
- The UKI names the exact system it boots. If the system on disk doesn't
  match, the boot stops; there is no fallback.
- The EFI System Partition is not encrypted and holds no private keys or
  user data.

> **Goal, not built:** ShapeBit's own shim, signed by Microsoft, so that a PC
> boots without the step that accepts the key. Computers move to it by an
> update, with their TPM enrollment.

## Releases

ShapeBit is a rolling release. A version is the time its build started, in
UTC, such as `202610301530`, and it names the commit it was built from.

### Channels

Released images are published to `ghcr.io/shapebit-software/os` under these
tags:

| Channel | What it holds | Moved by |
|---|---|---|
| `stable` | What installed computers update from | A person, by releasing a candidate, or by undoing a release |
| The version, such as `202610301530` | That release | Releasing |

Candidates wait in the private package `os/candidate`, and installers in the
private package `os/installer`, whose `stable` is the installer on the
download site ([Testing](Testing.md#packages)).

A release goes through these steps:

1. **Build.** Once a week, or when started by hand, a fresh build picks up
   Fedora's updates and is signed with the release keys.
2. **Test.** The image is tested on the path that installed computers take:
   the installer that people download installs `stable`, which then updates
   to the candidate ([Testing](Testing.md)). Only a build that passes every
   test gets a draft of its release notes. A newer candidate replaces it.
3. **Try.** A person reads the notes and can try the candidate on a real
   computer.
4. **Release.** A person copies the candidate, unchanged, to its version and
   to `stable`, and the release notes are published. Installed computers take
   it as their next update.
5. **Undo, if needed.** `stable` moves back to the release before, and the
   release is marked withdrawn. Installed computers take the previous release
   as their next update. A withdrawn build can't be released again.

Once a month, or when started by hand, a new installer is built from the
release that `stable` holds, and has its version. It is tested in full, and
after a person approves it, replaces the installer on the download site. There
is one installer per release: to fix the installer, a new release comes first.

Developers test updates with their own builds, through a local registry; it
is not a channel, and its builds can't be promoted.

### Release Identity

Today a release is identified by its image digest, and the tests check that
the system they ran on has exactly that digest.

> **Planned:** one signed, immutable **release manifest** per release, binding
> the version, the image digest, the UKI, and the system's root digest.
> Channels then only point to manifests; the updater accepts a release only if
> everything it downloaded matches its manifest, and the manifest format
> rejects unknown fields.

## Distribution

| What | Where | State |
|---|---|---|
| System images | GHCR, with the channels above | Built |
| Release notes | [GitHub releases](https://github.com/shapebit-software/os/releases): changes, checksums, and packages | Built |
| Sources | Next to each image and installer, for as long as it can be downloaded ([License](License.md#sources)) | Built |
| Installer | [download.shapebit.software](https://download.shapebit.software/shapebit-installer.img.xz), only the current installer | Built; the Installer workflow publishes it after approval |
| ShapeBit's own apps | A Flatpak repository of ShapeBit's own, built with [AetherPak](https://github.com/aetherpak/actions) | Decided; not built, as there are no such apps yet |
| ShapeBit's own packages | None: the image includes ShapeBit's components directly | Decided |

Third-party software comes from Fedora (into the image), and from Flathub and
Fedora's Flatpaks (onto the computer). ShapeBit doesn't mirror it.

## System Updates

- A computer checks `stable` soon after it starts and then every few hours,
  but not on a metered connection unless the person asks with **Check now**
  in Settings.
- A new release downloads and is staged in the background; the next restart
  or shutdown installs it. ShapeBit never restarts by itself and never ends a
  session for an update.
- The TPM unlocks the new release without re-enrollment, because its UKI
  carries TPM values signed by the same PCR key. Machine settings carry over.
- The previous release stays installed and can be started again.

Until release manifests exist, an update is accepted by where it comes from;
Secure Boot still checks the new UKI when it starts.

### Trial Boot and Health

> **Planned:** blocked upstream, as bootc and Fedora's SELinux policy don't
> support it yet.

A new release would boot on trial, with two attempts, using systemd's
Automatic Boot Assessment. It is accepted only once a health check passes and
stays passing for a short time: the release is the expected one, system
storage is present, critical services and the network stack run, and the
login screen is usable. Internet access and a login are not required. A clear
integrity failure rolls back at once; otherwise, once the attempts run out,
the computer starts the previous release. A failed release isn't staged
again until a newer one replaces it.

## Withdrawal and Revocation

- **Withdrawn**: a release with a quality problem is no longer offered, and
  computers go back to the release before (Undo, above). Built.
- **Revoked** (planned): a release that is unsafe to boot. Computers abandon
  it even if it's staged, fall back to a known-safe release or enter
  recovery, and keep signed revocation records, so a revocation applies
  offline too.

## Path to a Public Release

Done: the release keys exist and sign every candidate, with a separate key for
the TPM values. Every action in the workflows is pinned to a commit, and the
release keys are on the runner only for the builds that sign.

Before anyone outside ShapeBit's test machines installs:

- Back up the release keys offline.
- Require a hardware security key or passkey for everyone in the GitHub
  organization.
- Protect `main`, and require a reviewer to release.
- Sign release images, with computers refusing any others.
- Let updates replace shim, so that a revoked shim doesn't stop computers from
  booting.

Before a public release:

- Move the release keys to hardware-backed signing, so that no runner holds them.
- Replace the third-party Hyprland repository with Fedora's packages or
  ShapeBit's own builds.
- Get ShapeBit's own shim signed by Microsoft, including with Microsoft's 2023
  certificate, which newer PCs may trust alone.
- Test on a range of real PCs.
