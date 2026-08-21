# Diagnostics and Recovery

Rollback, repair, reset, independent recovery, Recovery Kit handling, diagnostic reports, and recovery authorization.

These pages are living architecture, not implementation evidence. Unlabeled
sections describe the current design. A **Proposed** label marks a section that
still requires explicit review and validation; remove the label once that review
is complete.

Changing a current rule requires updating its owning section and every affected
cross-area contract.

## On this page

- [Recovery model](#recovery-model)
- [Diagnostics](#diagnostics)

## Recovery model

### Separate Rollback, Backup, and Reset Operations

#### Purpose and constraints

System rollback, data restoration, and device reset solve three different problems. Combining them creates a risk of data loss.

#### Design

- **Roll back**, while a candidate remains unaccepted, selects its previous
  accepted baseline and preserves compatible prepared host state and all homes.
- **Repair system** restores the current system and boot artifacts while
  preserving `/etc`, `/var`, and all homes.
- **Reset system** clears system configuration and device state while
  preserving the encrypted home containers.
- **Remove user** removes one account and securely discards only that user's
  home.
- **Erase device** removes all device state and every user home.
- A filesystem snapshot is never the sole backup.

##### Reset and home rebinding

System reset preserves the encrypted containers plus a minimal, non-private
inventory containing the old public signing certificate or hash, account and
container identifiers, and previous role. It does not preserve the old local
`systemd-homed` private signing key or trust bindings.

The reset installation generates a new local signing key. The initial owner and
each additional user rebind their own home by proving possession of that home's
password or recovery key. The device recovery key never unlocks or rebinds a
user home.

##### Erase outcomes

The UI offers two distinct outcomes:

- **Erase and reinstall ShapeBit** performs cryptographic erase and installs
  the latest compatible, non-revoked stable release;
- **Erase without reinstalling** performs the erase and leaves no installed
  operating system.

Standard erase destroys cryptographic access. A separately selected verified
hardware sanitize operation may be offered when the device reports reliable
support. Reinstallation obtains the image from the network by default and
accepts signed USB media as an offline fallback; ShapeBit does not reserve a
large local factory image. Repair may restore the currently accepted release,
but erase-and-reinstall does not reinstall a known revoked release.

##### Authorization

| Action | Required authorization |
|---|---|
| diagnostics and boot-chain checks | none |
| rollback or repair | administrator credential or device recovery key |
| system reset | owner credential or device recovery key |
| recover or export one home | that user's credential or home recovery key |
| remove one user | owner credential plus explicit confirmation |
| erase device | owner credential or device recovery key plus explicit confirmation |

When initiated from the running system, privileged actions reauthenticate
through PAM. Destructive flows show the exact disk, require typed confirmation,
and verify adequate power before starting. Full erase destroys both device
state and every user-home container. No operation silently changes the meaning
of deployment rollback.

#### Tradeoffs

The recovery interface must clearly present the three separate operations and their effects.

### Independent Recovery Environment

#### Purpose and constraints

The trial rollback baseline may be insufficient when a failure affects the
bootloader, storage, encryption, or shared data. After durable acceptance, no
old deployment is guaranteed to remain compatible with committed host state.

#### Design

ShapeBit OS will provide a separate, minimal, independently versioned recovery image.

Recovery is outside normal deployment rotation and does not count as the
previous accepted deployment. It uses the same Secure Boot trust requirements
as the main system but has a distinct release profile and update lifecycle.

The initial recovery environment is a self-contained signed UKI stored on the
EFI System Partition. It must start without mounting the system LUKS2 volume or
its Btrfs filesystem and must contain no user secrets. The same signed recovery
environment is distributable as external USB recovery media. A separate
recovery partition is deferred unless the environment can no longer fit safely
on the ESP.

The ESP keeps two rotating recovery slots, `recovery-a` and `recovery-b`. An
update writes and verifies the inactive slot before changing selection, never
overwrites the accepted slot in place, and retains the previous recovery image
as fallback. Recovery images have candidate, accepted, and previous states in a
lifecycle independent of normal system deployments.

When a system release requires a newer compatible recovery version, recovery
rotation is a prerequisite transaction. ShapeBit writes and verifies the
inactive recovery slot and durably selects the compatible recovery image before
staging the system release. If recovery download, verification, writing, or
selection fails, the system release is not staged and the currently accepted
system remains unchanged.

Within manifest schema version 1, compatible recovery is also the bootstrap
executor when the running updater does not satisfy the target's updater
requirement. The current system rotates recovery and schedules a declared boot
into it; recovery then verifies and stages the target system release. Failure
before the target trial begins returns to the unchanged accepted system. This
flow does not install a temporary privileged updater in the running system.

The initial interface is a minimal offline-first TUI usable by local keyboard
and serial console. It can import a Recovery Kit from USB or accept manual key
entry. A later graphical interface must use the same backend. Remote recovery
is deferred and may never become the only recovery path.

#### Requirements

- independence from the main compositor;
- system-volume unlocking with the device recovery key;
- per-user home unlocking with that user's recovery key;
- storage diagnostics;
- deployment selection;
- authenticated reconstruction of signed boot-stack slots, generic UEFI
  fallback files, and firmware entries under [Release Artifact and Rootfs Binding](boot-system-lifecycle.md);
- recovery-assisted staging of a schema-v1 system release;
- reinstallation of a known image;
- data export;
- device erase with and without reinstallation.

The environment also exposes both erase outcomes defined by [Separate Rollback, Backup, and Reset Operations](diagnostics-recovery.md) and, while
a candidate remains unaccepted, the ability to retry it, boot its previous
accepted baseline once, abandon the pending update, and inspect its health
report.

Recovery mounts data read-only by default. Unlocking the system volume requires
the device recovery key when normal TPM2 authorization is unavailable.
Unlocking a user's home additionally requires that user's credential or recovery
key; the device recovery key never unlocks a per-user home.

Boot-chain diagnostics require no authentication. Writing repaired ESP files or
UEFI variables requires an administrator credential or the device recovery key
as defined by [Separate Rollback, Backup, and Reset Operations](diagnostics-recovery.md). Internal recovery can repair a partially usable ESP;
complete loss of its internal boot path requires the external USB form of the
same signed recovery environment.

#### Tradeoffs

Higher maintenance and storage costs, but a significantly better ability to repair the device.

#### Ownership boundaries

This section defines the independent environment. [Separate Rollback, Backup, and Reset Operations](diagnostics-recovery.md) defines the meaning and
authorization of rollback, repair, system reset, user removal, and device
erase. [Trial Boot and Explicit Deployment Acceptance](boot-system-lifecycle.md) defines automatic deployment rollback.

### Recovery Kit Presentation and Lifecycle

#### Purpose and constraints

The initial ShapeBit installation enrolls two independent recovery credentials:
one for the encrypted system volume and one for the first owner's encrypted
home. The user needs a simple way to save both credentials outside the new
computer without making them appear to be one interchangeable key. The
installer must also survive a frontend failure without persisting plaintext
recovery material or declaring completion before the current kit has been
presented.

#### Design

##### One logical kit, two independent keys

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

##### Trusted presentation

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

##### Saving methods

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

##### Acknowledgement and completion

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
kit again through [One-Shot Installer Secret Channel](boot-system-lifecycle.md)'s output channel.

##### Plaintext lifetime and interrupted presentation

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

##### Later users and replacements

An additional user receives a separate kit containing only that user's home
recovery key. The device recovery key is not re-presented during additional-user
creation.

A later recovery-key action is **Replace recovery key**, never **Show existing
recovery key**. Replacement enrolls and tests a new keyslot before revoking the
old one. Device and home recovery keys remain independently replaceable.

#### Tradeoffs

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

#### Ownership boundaries

This section owns the logical Recovery Kit, offline representation, presentation and
saving methods, acknowledgement, completion gate, interruption behavior, and
final plaintext lifetime. [Per-User Encrypted Homes](security-identity.md) and [TPM-Unlocked Encrypted System Volume](security-identity.md) own the independent home and
device recovery credentials. [One-Shot Installer Secret Channel](boot-system-lifecycle.md) owns their one-shot transport. [Installer Transaction Lifecycle](boot-system-lifecycle.md)
owns the installation transaction and verification. Detailed visual layout and
copy belong to the installer UI documentation.

## Diagnostics

### Diagnostic Reports and Consent

#### Purpose and constraints

ShapeBit must preserve useful evidence after boot, update, storage, service, and
desktop failures. Those reports can contain detailed operational context,
including logs, paths, user names, hardware, and network information. The
system needs bounded local retention, an explicit device-wide choice for
automatic upload, and practical exclusion of high-risk secrets without
claiming that arbitrary logs can be perfectly anonymized.

Minimal rollout telemetry under [Staged Stable Rollout](boot-system-lifecycle.md) remains a separate mechanism and
setting.

#### Design

##### Report envelope and payload ownership

All reports use one common envelope. It contains only:

- envelope format version;
- random report identifier and creation time;
- producing component and its interface version;
- event type and severity;
- ShapeBit release identity and deployment digest; and
- payload media type and producer-owned payload-schema version.

There is no common detailed payload schema. Each producer owns and versions its
payload, including any structured records or attachments needed for its event.
The diagnostics service validates the common envelope and packages the payload
without interpreting it as one universal system dump.

Producers collect only fields and log sources declared for their report type.
ShapeBit does not automatically attach the complete journal, a home directory,
a file listing, a memory dump, or other broad ambient state merely because it
is available.

##### Practical data protection

A detailed report may contain information useful for diagnosis, including:

- selected system logs;
- hardware models, drivers, and firmware details;
- process and service names;
- system and home paths;
- relevant network configuration and addresses;
- user names that occur in approved logs; and
- boot, update, transaction, and failure-stage history.

The following content is always prohibited:

- passwords and Recovery Kit material;
- private cryptographic keys;
- recognized authentication tokens, cookies, and session secrets;
- deliberately collected contents of private user documents;
- clipboard contents, screenshots, and audio or video capture; and
- form contents or text observed while the user types.

Producers must not open an ordinary user file solely to include its content.
Selected system logs remain allowed even though they can incidentally contain
user-supplied text. ShapeBit applies format-aware filters for known secret
fields and patterns, but does not promise perfect recognition of every secret
that another component may have written into a log. The global-consent UI
describes the allowed data categories and this residual risk.

##### Global upload consent

Detailed reports are always created and retained locally regardless of upload
consent. Automatic upload is disabled by default and controlled by one
device-wide setting. Only an active local administrator may change it through
the normal Polkit authorization flow.

Enabling the setting applies to reports created from that point onward. Reports
are then uploaded automatically without a per-report prompt and without a
content preview. Reports created before consent are not uploaded retroactively.

When consent is enabled, ShapeBit creates a random diagnostic installation
identifier. It is not derived from a hardware serial, TPM identity, MAC address,
user account, or other existing identifier. It lets the service correlate
reports from one installation and is visible in Diagnostics settings.

Disabling consent stops future upload, discards unsent outbound copies, and
deletes the local diagnostic installation identifier. It does not delete local
source reports or retract reports already received by the server. Re-enabling
consent, resetting the device, or reinstalling ShapeBit creates a new identifier.

##### Local retention

An ordinary local report expires 30 days after creation. The total ordinary
report store is limited to 2 GiB; when necessary, the oldest reports are removed
first. Successful upload does not shorten local retention.

A report attached to an unresolved active failure is protected from automatic
deletion. After the failure resolves, ordinary age and capacity rules apply. If
protected reports prevent compliance with the 2 GiB limit, ShapeBit preserves
them, rate-limits or deduplicates new equivalent reports, suppresses lower-
severity additions, and warns the administrator instead of deleting the active
evidence.

An administrator may explicitly delete all local diagnostic reports. Report
producers must rate-limit repeated failures and coalesce equivalent occurrences
so that a crash loop does not create an unbounded number of reports.

##### Server retention

The ShapeBit diagnostic service retains each full detailed report and its
diagnostic installation identifier for 90 days, then deletes both. It does not
retain the transport source IP address as diagnostic data or in a long-term
request log. Access to raw reports is restricted to the ShapeBit diagnostic
operator.

ShapeBit may retain derived aggregate statistics longer than 90 days only after
removing the diagnostic installation identifier, user names, paths, network
addresses, and free-form log text. Those aggregates are no longer treated as
full diagnostic reports.

##### Manual export

An active local administrator may export one report or a selected time range
regardless of the global upload setting. Selecting **Export** is the explicit
local-file action; ShapeBit shows no content preview.

The result is a standard `.tar.zst` archive containing common envelopes,
producer payloads, and a checksum manifest. It is created with permissions for
the exporting user only and is not encrypted by default. The UI warns that the
archive may contain logs, user names, paths, hardware details, and network data.
The same prohibited-content and known-secret filtering rules apply to export.

Reading or importing an archive never executes a contained program, script,
plugin, hook, or other payload code.

#### Tradeoffs

- One global choice enables useful automatic fault correlation without repeated
  consent dialogs.
- Users cannot inspect each report before upload and accept a stated residual
  risk that approved logs contain unexpected sensitive text.
- Component-owned payloads can evolve independently, while the common envelope
  keeps indexing and transport stable.
- Bounded local and server retention limits long-term accumulation.
- Active-failure evidence takes precedence over the ordinary local capacity
  limit, requiring producer rate limiting and low-space warnings.
- Manual archives remain compatible with standard tools but require careful
  handling because they are not encrypted by default.

#### Ownership boundaries

This section owns the common diagnostic envelope, producer payload boundary,
prohibited content, global detailed-report consent, diagnostic installation
identifier, local and server retention, and manual export. [Staged Stable Rollout](boot-system-lifecycle.md) owns minimal
rollout telemetry. [Capacity and Low-Space Policy](base-system.md) owns general capacity and low-space behavior.
[Platform-Service API Contract](base-system.md) owns the diagnostics service API and job lifecycle. Individual domain
architecture sections determine when a report is mandatory and which event-specific evidence is
useful.
