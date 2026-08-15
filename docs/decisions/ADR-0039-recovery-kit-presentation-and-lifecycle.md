# ADR-0039: Recovery Kit Presentation and Lifecycle

**Status:** Accepted

**Date:** 2026-08-14

## Context

The initial ShapeBit installation enrolls two independent recovery credentials:
one for the encrypted system volume and one for the first owner's encrypted
home. The user needs a simple way to save both credentials outside the new
computer without making them appear to be one interchangeable key. The
installer must also survive a frontend failure without persisting plaintext
recovery material or declaring completion before the current kit has been
presented.

## Decision

### One logical kit, two independent keys

The installer presents one logical **ShapeBit Recovery Kit** containing:

- the device recovery key for the system LUKS2 volume; and
- the first owner's recovery key for that owner's LUKS2 home.

The two keys are generated independently, remain separately labeled, and are
enrolled and tested independently. Neither key unlocks the other protected
volume. ShapeBit does not escrow either key.

The kit is a versioned, self-contained offline document. Its common header
identifies ShapeBit Recovery Kit, the format version, the installation or device
identifier needed to associate the kit with the computer, and the first owner
needed to associate the home key with its account. Its two labeled key records
and an integrity checksum follow the header. The checksum detects transcription
or scanning errors; it is not an authenticity proof and contains no network
lookup capability.

### Trusted presentation

One trusted installer screen presents the complete kit. It explains that anyone
holding a key can access its corresponding encrypted volume, that ShapeBit
cannot restore a lost kit, and that the two keys protect different targets.

The screen displays one QR code encoding the complete offline document. It does
not encode a URL, retrieval token, or server-side reference. Both keys can also
be revealed as clearly labeled text for manual recording. The QR code and text
are equally secret.

While recovery material is visible, the installer requests that the compositor
block screenshots and screen capture, and it hides the material if screen
sharing starts or the session locks. The initial flow does not offer clipboard
copying. These controls reduce accidental disclosure but do not protect against
a camera or a compromised display stack.

### Saving methods

Before installation can complete, the user must use at least one presentation
method:

- save a verified encrypted file on another attached storage device;
- send a complete paper form to a printer; or
- display the QR code and labeled text for manual saving.

The paper form carries the same QR code, both labeled textual keys, the common
header, and short recovery and storage warnings. The UI warns the user to use a
trusted printer and not to store the printout with the computer.

File export always encrypts the complete kit. It accepts a dedicated export
password entered twice and never reuses the owner account password. The password
is not retained. Export is permitted only to another attached storage device,
not the target system volume. After writing, the installer reads the file back,
checks its checksum, and verifies that it decrypts to the current kit before
reporting the export as verified.

The QR, printed form, and encrypted file represent the same logical document,
although their physical encodings may differ. The format is versioned so future
recovery tools can continue to import older supported kits.

### Acknowledgement and completion

After using a presentation method, the user must explicitly select **I saved my
Recovery Kit outside this computer**. The installer does not ask the user to
retype key fragments.

A verified encrypted export proves only that a readable encrypted copy was
written to the selected external device. Printing and manual saving cannot be
verified, and the UI must not describe them as verified backups. The
acknowledgement records only that the current kit was presented and acknowledged;
it stores neither recovery values nor the destination or method used.

The backend does not write the installation-complete marker or return
`completed` until the currently enrolled kit has been presented by at least one
method and acknowledged. Until then, the frontend may request the same current
kit again through ADR-0036's output channel.

### Plaintext lifetime and interrupted presentation

After enrollment, the backend retains both current recovery values only in
protected memory until presentation is acknowledged. This permits a restarted
frontend to show the same kit while the backend and installation transaction
remain alive. It never writes the plaintext values to the transaction journal,
logs, diagnostics, target filesystem, or temporary files.

After acknowledgement, the backend immediately zeroizes its plaintext copies,
finishes the installation, and cannot show those values again. The frontend
clears its copies when the presentation ends and in all cases no later than five
minutes after the screen closes. Generated files and printer output are user-
controlled external copies and are not retained by ShapeBit.

If the backend or computer restarts before acknowledgement, plaintext recovery
values are not restored from persistent installer state. Resume unlocks the
system through its verified TPM path and asks the owner to enter the home
password again. The backend then generates two new independent recovery keys,
enrolls and tests each new keyslot before revoking its previous unconfirmed
keyslot, and presents a new kit.

The installer clearly warns that every previously displayed, printed, or
exported unconfirmed kit from that interrupted attempt is now invalid. The new
kit becomes the only kit eligible for acknowledgement and completion. If safe
replacement and verification cannot be completed, the transaction fails rather
than accepting the old presentation.

### Later users and replacements

An additional user receives a separate kit containing only that user's home
recovery key. The device recovery key is not re-presented during additional-user
creation.

A later recovery-key action is **Replace recovery key**, never **Show existing
recovery key**. Replacement enrolls and tests a new keyslot before revoking the
old one. Device and home recovery keys remain independently replaceable.

## Consequences

- The user handles one understandable Recovery Kit without weakening the
  cryptographic separation of system and home recovery.
- Recovery remains possible without ShapeBit infrastructure, an account, or an
  Internet connection.
- Installation completion includes an explicit human handoff of the current
  recovery material, but it does not falsely claim that a printout or manual
  copy is readable and safely stored.
- An installer-backend restart before acknowledgement invalidates any earlier
  unconfirmed copy and requires the owner password again, but avoids persisting
  plaintext recovery values.
- Encrypted export is safer than plaintext removable-media export but introduces
  a second password that the user must retain.
- Screen-capture controls reduce common accidental leaks but cannot prevent
  photography or disclosure through a compromised trusted UI.

## Boundaries

This ADR owns the logical Recovery Kit, offline representation, presentation and
saving methods, acknowledgement, completion gate, interruption behavior, and
final plaintext lifetime. ADR-0011 and ADR-0012 own the independent home and
device recovery credentials. ADR-0036 owns their one-shot transport. ADR-0037
owns the installation transaction and verification. Detailed visual layout and
copy belong to the installer UI documentation.

## Related decisions

- [ADR-0010](ADR-0010-dioxus-installer.md)
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0012](ADR-0012-encrypted-system-volume.md)
- [ADR-0016](ADR-0016-initial-installation-and-storage-profile.md)
- [ADR-0036](ADR-0036-one-shot-installer-secret-channel.md)
- [ADR-0037](ADR-0037-installer-transaction-lifecycle.md)
