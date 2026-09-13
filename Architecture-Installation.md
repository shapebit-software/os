# Installation

Installing ShapeBit means an unprivileged installer window (the frontend)
talks to a privileged backend that does the actual work. This page covers
their shared protocol, how passwords and keys are handled safely, how the
target disk is chosen and confirmed, and how the install itself proceeds
from start to finish without leaving the disk in an unknown state.

## Protocol

The frontend and backend talk JSON Lines over a private local Unix socket:
one line, one complete JSON object.

A normal response or event looks like:

```json
{"version":1,"message":"installer.writing-system","payload":{"progress":42}}
```

An error has no `message` field, and a stable `code` instead:

```json
{"version":1,"code":"disk-changed","payload":{"disk_model":"Example NVMe"}}
```

Events come in four kinds: `step-started`, `step-completed`,
`step-cancelled`, `progress`.

## The Installation Plan

The plan holds only choices the user actually made:

- the capability scan it was built from;
- the disk to install on;
- locale, time zone, and keyboard layout;
- the computer's name;
- the first owner's user name and display name; and
- an optional installer-created Wi-Fi profile to keep for that owner.

## What the Backend Reports (Capabilities)

Before showing any choices, the frontend asks the backend what's possible.
The answer includes:

- a protocol version and a fresh scan ID;
- installer and target ShapeBit version and digest;
- each disk, with its ID, model, capacity, and whether it's eligible (and
  why not, if not);
- whether UEFI, Secure Boot, and TPM2 are available;
- whether there's a working internet connection;
- available Wi-Fi adapters and whether scanning works; and
- the supported locales, time zones, and keyboard layouts.

## Optional Wi-Fi

If there's no working internet connection, the frontend offers a Wi-Fi step.
The user can connect or skip it — lack of internet never blocks
installation.

## Sending Passwords and Keys Safely

Passwords, Wi-Fi credentials, recovery keys, and anything derived from them
never travel over the ordinary JSON Lines connection, and never end up in
the plan, a capability snapshot, an event, an error, logs, or diagnostics.
Instead, each one crosses over a separate, one-shot channel.

### How a one-shot transfer works

For each secret, the backend opens a brand-new private Unix socket used for
exactly one transfer. The frontend only gets a handle back — a purpose, a
direction, a size limit, and an expiry. It never sees the secret itself over
the ordinary connection.

The socket lives in a runtime directory only the backend can reach. The
backend checks who's actually connecting and ties the request to the
current frontend, plan, purpose, and direction. It expires after two
minutes, accepts exactly one connection and one value, and then closes for
good — a handle can't be reused or replayed.

### Direction and purpose

Every request declares one direction and one purpose:

| Purpose | Direction | Max size |
| --- | --- | --- |
| `owner-password` | frontend → backend | 1 KiB |
| `wifi-password` | frontend → backend | 1 KiB |
| `recovery-kit` | backend → frontend | 16 KiB |

The frontend can't change the purpose, direction, or destination, and a
secret accepted for one purpose is never reused for another — even if the
owner and Wi-Fi passwords happen to be identical, they're still sent
separately. Adding a new purpose means extending the protocol; there's no
generic catch-all "secret" purpose.

### What actually goes over the wire

Just a length, then exactly that many bytes — no JSON, field names, or
metadata. Anything that doesn't match (stream cut short, trailing bytes, bad
encoding, over the size limit) invalidates the request and discards
whatever was received.

### What happens to a secret afterward

The frontend clears its input fields and wipes its buffers as soon as a
transfer succeeds. The backend then owns the only copy: it keeps it in
memory only, excludes it from core dumps, locks its pages where it can, and
wipes it when done.

An accepted secret is deleted right after it's used, and never lives longer
than 30 minutes even if unused — past that, the backend reports
`secret-unavailable` and the frontend asks again. Leaving the input screen,
editing an already-sent value, disconnecting, restarting the backend, or
cancelling all throw away any pending secret. A failed use (say, a rejected
Wi-Fi password) throws it away too — the backend never keeps a failed
password around to retry automatically.

Losing a secret this way doesn't by itself force anything destructive to
restart; whether the install waits for a replacement, stops, or pushes
through is decided by the install lifecycle rules further down this page.

Because the channel relies on local Unix permissions rather than
cryptographic sealing, it protects a secret in transit — it can't protect a
secret already in use if the frontend or backend process itself is
compromised.

### Recovery Kit output

Once the backend generates and enrolls the device recovery key and the
first home's recovery key, it sends their presentation package once, as an
`output` / `recovery-kit` transfer. The frontend holds onto that package
only long enough to show it to the user, then wipes it.

If the frontend loses the package before the user has confirmed seeing it,
the backend doesn't quietly generate replacement keys — it can resend the
same already-enrolled keys as long as it's still running. If the backend
itself restarts before that confirmation, it replaces the keys safely
instead of trying to restore old plaintext from disk.

### Confirming the owner password

The frontend asks for the password twice and compares the two fields
itself, sending a single copy to the backend only once they match. The
backend checks that one copy against its own rules; it never receives a
second copy to compare. Paste, password managers, and a temporary "reveal"
action all still work. Leaving the screen, or a successful send, clears both
fields. If the backend rejects the password, the user enters and confirms
it again. The Wi-Fi password, by contrast, is only ever asked once.

## Choosing and Confirming the Disk

Installing erases one whole disk, and Linux device names like
`/dev/nvme0n1` aren't permanent — they can change as storage is attached,
removed, or rediscovered. So the plan, and the destructive confirmation that
follows it, stay bound to the actual physical device the user reviewed, not
to a device name.

### Identifying a disk

For every disk, the backend records:

- a stable udev identifier, preferring WWN when one exists;
- hardware serial number;
- model;
- exact byte capacity;
- transport or bus type;
- whether it's internal, external, or removable; and
- its current kernel device path, kept only for display — never used as
  identity.

Before accepting a plan, issuing a confirmation, and again right before the
destructive step, the backend re-resolves the disk and compares the full
record. If the stable identifier, serial, capacity, transport, or
internal/external/removable class changed, it returns `disk-changed` and
clears the selection and confirmation. A disk with conflicting identifiers,
ambiguous multipath presentation, read-only media, or active use that can't
be safely released isn't eligible at all.

Some drives don't expose a trustworthy WWN or serial. Those stay eligible
only while the rest of their identity is unique in the current scan — the UI
marks the identity "incomplete" and requires an extra acknowledgement on the
final screen. It's a usability concession, not a promise of stable identity
across an arbitrarily rearranged machine.

### Which disks are allowed

An eligible target is either an internal disk, or an external USB,
Thunderbolt, or eSATA disk that's clearly labelled as external and meets the
same capacity and validation rules. Never eligible: the disk the running
installer itself booted from, read-only devices, ambiguous multipath
devices, or anything with mounts, swap, or other active use the backend
can't prove it can safely release. Nothing is preselected, and an
external or removable target adds one more acknowledgement: disconnecting
during installation can leave it half-done, and disconnecting afterward
means ShapeBit won't boot.

### The final confirmation screen

Right before the destructive step begins, the frontend shows one screen
with:

- ShapeBit OS as what's being installed;
- disk model and exact, human-readable capacity;
- serial number, if known;
- internal, external, or removable; and
- a plain statement that the whole disk will be erased, irreversibly.

The user ticks **I understand that all data on this disk will be deleted**
before **Erase disk and install ShapeBit** becomes available — there's no
typed model name, serial, or "ERASE" phrase to type. An incomplete identity
or an external/removable target adds its own acknowledgement on the same
screen, on top of (not instead of) that checkbox.

The backend, not the UI, then issues a one-use token bound to the exact disk
identity, capability scan, plan, and target release digest, and to itself as
the running backend instance. It expires after 10 minutes, and any
mismatch, expiry, disconnect, or backend restart invalidates it. It
authorizes exactly one entry into the destructive phase and can't be reused.

### When the plan goes stale

The plan and disk selection go stale if any storage device is attached or
removed, the selected disk's identity or eligibility changes, it becomes
mounted or otherwise in use, the target release digest changes, required
UEFI/Secure Boot/TPM2 availability changes, the backend restarts, or the
user picks a different target. An unrelated monitor, input device, or
general network change doesn't count, and Wi-Fi scan results are handled
separately from the storage plan.

Going stale clears the disk selection and every acknowledgement and token,
but keeps unrelated safe choices — locale, time zone, keyboard, computer
name, first-owner names. The user rescans, reselects, and confirms again.
The backend also runs one last identity, eligibility, and active-use check
immediately before the first destructive write; if that fails, nothing
destructive happens.

### Picking up an interrupted install

If a valid transaction journal (see [Installing](#installing) below) already
shows this exact disk mid-install, continuing it doesn't ask the user to
re-authorize the original erase — but it does recheck identity and every
already-completed step. Choosing **Start over**, losing reliable identity,
or having no valid journal all require a fresh scan and a fresh final
confirmation.

## Installing

An installation moves through six phases, in order:

```text
validating → preparing → creating-storage → installing-system → configuring → verifying
```

- **validating** rechecks the plan, scan, disk, inputs, and policy —
  nothing changes yet.
- **preparing** gathers any remaining non-secret inputs — the target is
  still untouched.
- **creating-storage** erases the disk and lays down the GPT, the system
  LUKS2 volume, Btrfs, and encrypted-home storage (see
  [Base System](base.md) for that layout).
- **installing-system** writes the ShapeBit image and boot artifacts.
- **configuring** sets up the first owner, their home, an optional Wi-Fi
  profile, TPM2, trust, and recovery.
- **verifying** checks the whole installation and syncs it before declaring
  success.

The backend alone decides phase and step state — the frontend can present
it, but can't skip, reorder, or mark anything complete. Only one
installation runs per target disk at a time.

### The destructive boundary

`validating` and `preparing` are non-destructive and offer an ordinary
**Cancel**. The final disk confirmation above is what authorizes the one
transition into `creating-storage` — entering that phase is the point of no
easy return.

After that, ordinary cancellation goes away. Closing or crashing the UI
doesn't stop the backend, which keeps going safely; reconnecting just
reattaches to the same installation and its history. The UI may still offer
a clearly-serious **Stop installation** action, which requests a controlled
stop at the next safe point the backend declares — the disk may end up
incomplete and unbootable, needing resume or reinstallation, and stopping
never restores the disk's previous contents. Power loss, a backend crash, or
losing the live environment counts as an interruption, not a cancellation.
Either way, any pending secret requests are discarded per the rules above.

### The journal

Before the destructive boundary, nothing needs to be saved durably — the
target hasn't changed, so the plan can simply be started again. After the
boundary, the disk itself carries a small, durable, secret-free journal,
written as early as it's safe to and synced after every completed
checkpoint.

The journal records only: transaction and protocol IDs, the target release
digest, the disk's identity record, which phases and steps finished, an
event sequence number, the current state, and safe last-error/retry
details. It never records passwords, Wi-Fi credentials, Recovery Kit
values, derived keys, raw command output, or sensitive logs.

A step counts as done only once its effect is verified and its checkpoint
is durably synced — leftover files with no matching checkpoint prove
nothing. If an interruption happens before any valid journal exists, the
disk is simply an incomplete target that needs a fresh, confirmed start.

### Resuming

On startup, the installer looks for a valid, incomplete ShapeBit journal on
any eligible disk and offers:

- **Continue installation**, which rechecks disk identity, release inputs,
  journal integrity, and every already-completed checkpoint before moving
  on; or
- **Start over**, which requires a fresh destructive confirmation and
  reinstalls onto the already-modified disk.

Continuing resumes right after the last verified checkpoint. A phase that
was interrupted before its checkpoint simply runs again, following its own
recovery rule — an incomplete `creating-storage`, for instance, can restart
from scratch, since that data was already irreversibly gone anyway. The
backend never assumes a step finished just because it sees matching files.

If the recorded state no longer matches what's on disk, the disk identity
changed, or the journal is incompatible with the running installer, resume
is blocked with a clear explanation, and starting over is offered instead of
an unsafe attempt to reuse the old transaction.

### Retrying and failing

The backend classifies each step in advance as safely retryable or terminal
— the frontend never guesses. Resumable downloads may continue on their
own. A missing secret (`secret-unavailable`) pauses at a safe point and asks
for another one-shot transfer, if the installation can wait. A retryable
failed step offers **Try again**, rechecks its preconditions, and stays part
of the same installation — there's no fixed retry limit, as long as retrying
stays safe and the user is the one choosing to. An integrity failure, a
changed disk identity, or a serious, unclassified storage error is never
retried automatically; the installation moves to `failed` instead, keeping
its diagnostics and journal until the user retries, resumes later, or
confirms starting over. Failing never triggers another erase by itself.

### Verifying and finishing

Before declaring success, `verifying` confirms at least:

- the GPT, LUKS2, and Btrfs identities and layout are correct;
- the installed image matches its exact digest;
- the required signed UKIs, systemd-boot entries, and recovery assets are
  present;
- the system and first-home keyslots work;
- TPM2 unlock and both enrolled recovery credentials work;
- the first owner exists and their encrypted home is active;
- their Wi-Fi profile was saved, if that was requested; and
- everything is synced and target filesystems are safely unmounted.

Internet access isn't required to finish, and testing the recovery
credentials must never reveal their values or invalidate the working
keyslots.

Once every check passes, the user still has to see and acknowledge the
Recovery Kit before the backend writes a durable installation-complete
marker, reports the terminal `completed` result, and removes the now-unneeded
journal. If something interrupts between those last steps, the completion
marker wins, and the stale journal can be safely cleaned up.

Finishing installation means the disk itself checks out completely — it
isn't proof that this particular physical machine has actually completed a
real first boot, which is covered separately by hardware and QEMU testing.
