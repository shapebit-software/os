# Installer

The unprivileged frontend and privileged installer backend need one
testable local protocol.

### Design

#### Transport and common messages

The ordinary installer protocol uses JSON Lines over a private local Unix
socket. Each line is one complete JSON object.

A successful request, response, or event has at least:

```json
{"version":1,"message":"installer.writing-system","payload":{"progress":42}}
```

An error has no `message` field and has at least:

```json
{"version":1,"code":"disk-changed","payload":{"disk_model":"Example NVMe"}}
```

#### Minimal InstallationPlan

The `InstallationPlan` payload contains only choices made by the user:

- the capability-scan identifier;
- the opaque identifier of one disk returned by that scan;
- locale, time zone, and keyboard layout identifiers advertised by the backend;
- computer name;
- first-owner user name and display name; and
- an optional installer-created Wi-Fi profile identifier with
  `save_for_owner`.

#### Capabilities

One `Capabilities` response describes the backend snapshot used to build a
plan. It contains:

- protocol version and a fresh opaque scan identifier;
- installer and target ShapeBit release version and digest;
- disks with opaque identifier, display model, capacity, eligibility, and a
  stable blocking-reason code when ineligible;
- availability of UEFI, Secure Boot, and TPM2;
- current Internet connectivity;
- available Wi-Fi adapters and whether scanning is possible; and
- supported locale, time zone, and keyboard-layout identifiers.

#### Optional installer Wi-Fi

When no working Internet connection exists, the frontend offers a Wi-Fi step. The user may connect or skip it; lack of Internet does not block installation.

The event kinds are:

```text
step-started
step-completed
step-cancelled
progress
```

## One-Shot Installer Secret Channel

### Purpose and constraints

Installer keeps passwords, Wi-Fi credentials, recovery keys, and derived secrets out of the serializable installation plan and ordinary JSON Lines protocol. 

The installer still needs a small local mechanism to transfer user-entered secrets o the privileged backend and generated Recovery Kit material in the opposite direction without temporary files, environment variables, event history, or diagnostic capture.

### Design

#### One-shot channel

The privileged backend creates a unique private Unix socket for one secret
transfer. The ordinary authenticated installer connection receives an opaque
request handle, purpose, direction, size limit, and expiry; it never receives
the secret itself.

The socket is created in a backend-owned runtime directory inaccessible to
other users. The backend validates Unix peer credentials and binds the request
to the authorized frontend, current installation plan or transaction, declared
purpose, and direction. The request expires after two minutes. It accepts one
successful connection and one value, then closes and removes the socket. A
handle cannot be replayed or reused.

No secret-channel socket listens on the network. Secret values never enter the
ordinary JSON Lines connection, `InstallationPlan`, capability snapshot,
events, errors, transaction state, logs, diagnostics, analytics, command-line
arguments, environment variables, or temporary files.

#### Direction and purpose

Every request declares one direction:

- `input`: the frontend sends a user-entered secret to the backend; or
- `output`: the backend sends generated Recovery Kit material to the frontend.

Every request also declares exactly one purpose. The initial input purposes are
`owner-password` and `wifi-password`; the initial output purpose is
`recovery-kit`. The frontend cannot change the purpose, direction, destination,
plan binding, or transaction binding. A secret accepted for one purpose is
never reused for another. Equal owner and Wi-Fi passwords are still transferred
as independent values.

New purposes require an explicit protocol extension. There is no unrestricted
generic `secret` purpose.

#### Binary framing and limits

The one-shot stream contains a fixed-size unsigned length followed by exactly
that number of bytes. It contains no JSON, field name, log text, or metadata.
End of stream before the declared length, trailing bytes, invalid purpose-
specific encoding, or a size beyond the declared maximum invalidates the
request and discards the received bytes.

Initial maximum sizes are:

- 1 KiB for `owner-password`;
- 1 KiB for `wifi-password`; and
- 16 KiB for `recovery-kit`.

The limits bound memory use without imposing an unnecessarily short Unicode
password limit. Purpose-specific semantic validation occurs only after the
complete bounded value has been received.

#### Input ownership and lifetime

Before transfer, the frontend owns user-entered plaintext. After successful
transfer, the backend owns the accepted copy and the frontend immediately
clears its input fields and makes a best-effort zeroization of backing buffers.
The backend retains plaintext only in memory, excludes it from core dumps,
locks its pages where supported, avoids unnecessary copies, and zeroizes each
buffer when released.

An accepted input secret is deleted immediately after its declared use and has
an absolute maximum backend lifetime of 30 minutes. If it has not been consumed
by then, the backend reports `secret-unavailable` and the frontend requests it
again. A successful provisioning step persists only its intended result: the
owner credential in the home-authentication design or the Wi-Fi credential in
the first owner's encrypted profile.

Moving back from an input screen, cancelling the field, editing an already sent
value, disconnecting the frontend, restarting the backend, or cancelling the
installation invalidates unused input requests and values. Editing creates a
new request and deletes the old accepted value immediately. A failed use, such
as rejected Wi-Fi authentication, also deletes the value; retry requires a new
transfer. The backend does not retain a failed password for an automatic later
attempt.

Loss of a secret does not itself restart a destructive phase or reformat a
disk. [Installer Transaction Lifecycle](#installer-transaction-lifecycle) determines whether the transaction can wait safely for a
replacement, must stop, or must continue through recovery.

#### Recovery Kit output

After the backend generates and enrolls the independent device and first-home
recovery keys, it transfers their presentation package through one
`output/recovery-kit` request. The package preserves the distinction between the
two keys even when [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md) presents them as one logical Recovery Kit.

The frontend retains the package only for the trusted presentation flow and
zeroizes it after that flow ends. If the frontend loses the package before
presentation is acknowledged, the backend does not silently rotate or generate
new enrolled keys. It may issue another one-shot output request for the same
temporarily retained keys. Unlike unused input, these already-enrolled output
keys survive a frontend reconnect while the backend remains alive, as defined
by [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md). A backend restart before acknowledgement invokes [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md)'s safe
key replacement instead of restoring plaintext from persistent state.

#### Owner-password confirmation

The frontend asks for the owner password twice and compares the two fields
locally. It transfers one copy only after they match. The backend validates the
single received value against the accepted encoding, length, and password
policy; it does not receive a confirmation copy.

Paste, password managers, and an explicit temporary reveal action remain
available. Leaving the screen or successful transfer clears both fields and
their backing buffers on a best-effort basis. A backend rejection requires the
user to enter and confirm the password again. Wi-Fi passwords are entered once.

### Tradeoffs

- Ordinary protocol capture and mock-plan fixtures contain no credentials or
  recovery material.
- One socket, one direction, one purpose, one value, and one expiry make replay
  and accidental cross-use easy to reason about.
- The design avoids more complex file-descriptor or `memfd` transfer in the
  initial installer.
- Unix peer credentials and filesystem permissions protect the local channel,
  but compromise of the authorized frontend or backend can still expose a
  secret while it is legitimately in use.
- The 30-minute input limit may require the user to re-enter a password after a
  long pause.
- Recovery Kit plaintext has a narrowly scoped lifetime across frontend
  reconnects; [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md) closes that lifecycle and defines safe replacement after
  a backend restart.

### Ownership boundaries

This section owns the installer secret transport, direction and purpose binding,
framing, initial size and expiry limits, input ownership and lifetime,
cancellation, and local password confirmation. [GTK 4 as the ShapeBit OS Installer Frontend](installer.md) owns the installer
privilege boundary. [Minimal Installer Protocol](installer.md) owns ordinary messages. [Installer Transaction Lifecycle](#installer-transaction-lifecycle) owns transaction
waiting and interruption. [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md) owns Recovery Kit presentation and final
secret lifetime.

## Installer Disk Identity and Confirmation

### Purpose and constraints

The initial installer erases one complete selected disk. Linux device names
such as `/dev/nvme0n1` are enumeration results, not persistent identities, and
can change when storage is attached, removed, or rediscovered. A plan and its
destructive confirmation must therefore remain bound to the actual device the
user reviewed, including when the target is external or lacks a reliable serial
number.

### Design

#### Disk identity record

The privileged backend creates an opaque disk identifier from a captured
identity record. The record contains every available authoritative hardware
property and the display properties needed for confirmation:

- udev stable storage identifiers, preferring WWN where available;
- hardware serial number;
- model;
- exact byte capacity;
- transport or bus type;
- internal, external, or removable classification; and
- current kernel device path for display and access only.

The kernel path is never identity evidence. Before accepting a plan, issuing a
confirmation, and crossing the destructive boundary, the backend resolves the
opaque identifier again and compares the complete required record.

A changed stable identifier, serial number, exact capacity, transport class, or
internal/external/removable classification returns `disk-changed` and clears
selection and confirmation. A disk with conflicting identifiers, ambiguous
multipath presentation, read-only media, or active use that cannot be safely
released is ineligible in the initial installer.

Some devices expose neither a trustworthy WWN nor serial. They remain eligible
only when the remaining composite identity is unique in the current scan and
continues to match. The UI marks the identity as incomplete and requires a
separate acknowledgement on the final screen. This is a usability concession,
not a claim of stable identity across arbitrary hardware rearrangement.

#### Eligible targets

The initial installer may target an internal disk or an eligible external USB,
Thunderbolt, or eSATA disk. External and hardware-removable targets are clearly
labelled. They must meet the same minimum capacity and ordinary validation as an
internal disk.

The storage device containing or backing the running installer environment is
never eligible. Neither are read-only devices, ambiguous multipath devices, or
targets with mounts, swap, holders, or other active use that the backend cannot
prove safe to release before confirmation.

An external or removable target adds a separate acknowledgement that disconnect
during installation can leave the disk incomplete and disconnect afterward
prevents ShapeBit from booting. No target is preselected.

#### Final destructive confirmation

Immediately before `creating-storage`, the frontend shows one final screen with:

- ShapeBit OS as the system to install;
- disk model and exact human-readable capacity;
- serial number when available;
- internal, external, or removable classification; and
- an explicit statement that the complete disk and all its data will be
  irreversibly erased.

The user must select **I understand that all data on this disk will be
deleted** before enabling **Erase disk and install ShapeBit**. The installer does
not require typing a model, serial, `ERASE`, or another confirmation phrase.

An incomplete hardware identity or external/removable target requires its
additional acknowledgement on the same screen. These acknowledgements do not
replace the ordinary destructive checkbox.

The backend, not the UI, issues a one-use confirmation token bound to the exact
disk identity record, capability scan, plan, target release digest, and active
backend instance. It expires after 10 minutes. Any mismatch, expiry,
disconnection, or backend restart invalidates it. The token authorizes only the
single transition into `creating-storage` for that transaction and cannot be
replayed.

#### Stale plan and rescan rules

The capability snapshot and disk selection become stale when:

- any storage device is attached or removed;
- any selected-disk identity or eligibility property changes;
- the selected disk becomes mounted, active, read-only, or otherwise in use;
- the target ShapeBit digest changes;
- required UEFI, Secure Boot, or TPM2 availability changes;
- the privileged backend restarts; or
- the user changes the selected target.

An unrelated monitor, input device, or network-state change does not make the
disk plan stale. Dynamic Wi-Fi results remain outside the storage snapshot as
defined by [Minimal Installer Protocol](installer.md).

When a plan becomes stale, the installer preserves unrelated safe form values,
including locale, time zone, keyboard choice, computer name, and first-owner
names. It clears the disk selection and every destructive acknowledgement and
token. The user must rescan, select the target again, and repeat final
confirmation.

The backend performs one final identity, eligibility, and active-use check
after consuming the confirmation token and immediately before the first
destructive write. A failure performs no destructive operation.

#### Interrupted installations

A valid [Installer Transaction Lifecycle](#installer-transaction-lifecycle) transaction journal identifies an already modified target with
the same disk identity record. Continuing that exact transaction does not ask
the user to authorize the original erase again, but it revalidates identity and
every completed checkpoint. Choosing **Start over**, losing reliable target
identity, or lacking a valid journal requires a new scan and final destructive
confirmation.

### Tradeoffs

- Device enumeration changes cannot silently redirect a confirmed erase to a
  different disk.
- The confirmation screen remains readable and does not rely on ritual text
  entry.
- Hot-plugging any storage device intentionally invalidates the selection,
  which is conservative but may require repeating the final step.
- External installation remains possible, with its disconnect risk made
  explicit.
- Devices without stable identifiers remain usable under a visibly weaker,
  current-scan-only identity rule.
- A backend restart cannot reuse an old destructive authorization.

### Ownership boundaries

This section owns target-disk identity, eligibility checks related to identity and
active use, external-target warnings, final destructive confirmation, token
expiry, and stale-plan behavior. [Initial Installation and Storage Profile](base-system.md) owns whole-disk installation and the
storage profile. [Minimal Installer Protocol](installer.md) owns the capability and plan envelopes. [Installer Transaction Lifecycle](#installer-transaction-lifecycle) owns
transaction phases, interruption, and continuation after destruction.

## Installer Transaction Lifecycle

### Purpose and constraints

Once the installer starts erasing the selected disk, closing the UI, losing
power, or retrying an unsafe step must not create a second uncontrolled
operation or a false success result. The initial lifecycle needs understandable
phases, one explicit destructive boundary, durable progress without secrets,
and conservative recovery rather than a general rollback mechanism.

### Design

#### Installation phases

One installation transaction advances through these ordered phases:

```text
validating
preparing
creating-storage
installing-system
configuring
verifying
```

- `validating` rechecks the plan, capability snapshot, selected disk, required
  inputs, and current policy without changing the target;
- `preparing` obtains available non-secret inputs and prepares the operation
  while leaving the target unchanged;
- `creating-storage` erases the selected disk and creates the GPT, system LUKS2,
  Btrfs layout, and encrypted-home storage foundations;
- `installing-system` writes the exact ShapeBit image and boot artifacts;
- `configuring` provisions the first owner, home, optional Wi-Fi profile, TPM2,
  trust, recovery, and device configuration; and
- `verifying` checks the complete installation and synchronizes it before
  success.

The backend is the authority for phase and step state. The frontend presents
events but cannot skip, reorder, or mark a phase complete. There is only one
active transaction for a selected target disk.

#### Destructive boundary and stopping

`validating` and `preparing` are non-destructive and expose ordinary **Cancel**.
[Installer Disk Identity and Confirmation](#installer-disk-identity-and-confirmation)'s final disk confirmation authorizes one transition into
`creating-storage`; beginning that phase is the destructive boundary.

After the boundary, ordinary cancellation is unavailable. Closing or crashing
the UI does not stop the privileged backend, which continues when it can do so
safely. A reconnected UI attaches to the same transaction and reads its current
state and event sequence.

The UI may expose a separate strongly warned **Stop installation** action after
the boundary. It requests a controlled stop at the next backend-declared safe
point. The disk may remain incomplete and unbootable and will require resume or
reinstallation. Stopping does not restore the disk's previous contents.

Power loss, backend termination, or loss of the live environment is an
interruption, not cancellation. Cancelling or stopping invalidates all
unneeded secret requests and plaintext according to [One-Shot Installer Secret Channel](#one-shot-installer-secret-channel).

#### Durable transaction journal and checkpoints

Before the destructive boundary, transaction state is temporary because the
target has not changed and the plan can be started again. After the boundary,
the target disk carries a small durable, secret-free installation journal. The
backend establishes its durable location as early as the storage layout safely
allows and synchronizes it after every completed checkpoint.

The journal records only:

- transaction and protocol identifiers;
- target release digest;
- the [Installer Disk Identity and Confirmation](#installer-disk-identity-and-confirmation) target-disk identity;
- completed phase and step identifiers;
- monotonic event sequence;
- current lifecycle state; and
- safe last-error and retry metadata.

It never contains passwords, Wi-Fi credentials, Recovery Kit values, derived
keys, raw command output, or sensitive logs.

A step is complete only after its effects are verified and its checkpoint is
durably synchronized. Files or partitions observed without a matching valid
checkpoint do not prove completion. If interruption happens before a valid
journal can be established, the disk is treated as an incomplete target that
can only be started again after [Installer Disk Identity and Confirmation](#installer-disk-identity-and-confirmation) confirmation.

#### Resume and start over

On startup, the installer scans eligible disks for a valid incomplete ShapeBit
installation journal. It offers:

- **Continue installation**, which revalidates disk identity, release inputs,
  journal integrity, and already completed checkpoints before proceeding; or
- **Start over**, which requires a new destructive confirmation and recreates
  the installation on the already modified disk.

Continue begins after the last verified checkpoint. A phase interrupted before
its checkpoint runs again according to its declared idempotent recovery rule.
In particular, incomplete `creating-storage` may be recreated from the
beginning because the previous data was already irreversibly lost. The backend
never guesses completion from residual files.

If required artifacts no longer match the journal, the disk identity changed,
or the recorded operation is incompatible with the running installer, resume
is blocked. The UI explains the stable reason and may offer start over, not an
unsafe conversion of the old transaction.

#### Waiting, failure, and retry

The backend classifies each step in advance as safely retryable or terminal
under specified preconditions. The frontend does not infer this classification.

- resumable network downloads may continue automatically;
- `secret-unavailable` pauses at a safe point and requests a new one-shot
  transfer when the transaction can wait;
- a retryable failed step exposes **Try again**, revalidates its preconditions,
  and remains part of the same transaction;
- there is no fixed retry-count limit while repeated attempts remain safe and
  require informed user action; and
- integrity failure, disk-identity change, or serious unclassified storage I/O
  failure is not retried automatically and moves the transaction to `failed`.

A failed transaction retains its diagnostic reference and journal until the
user chooses a permitted retry, resumes later, or confirms start over. Failure
does not initiate another format operation by itself.

#### Verification and completion

The `verifying` phase confirms at minimum:

- the expected GPT, LUKS2, and Btrfs identities and layout;
- the exact installed image digest;
- required signed UKIs, systemd-boot entries, and recovery assets;
- valid system and first-home keyslots;
- usable TPM2 system unlock and both enrolled recovery credentials;
- the first-owner record and activation of its encrypted home;
- the first-owner Wi-Fi profile when preservation was requested; and
- synchronized data followed by safe unmounting of target filesystems.

Internet access is not a completion requirement. Recovery-credential testing
must not disclose values or revoke the working keyslots.

After every verification succeeds, [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md)'s presentation gate requires the
current Recovery Kit to be presented and acknowledged. Only then does the
backend durably write an installation-complete marker, emit the terminal
`completed` result, and remove the resumable transaction journal. If
interruption occurs between those actions, the complete marker takes precedence
and permits safe cleanup of the stale journal.

Installer completion means that required disk state was verified. It is not
evidence that the particular physical computer completed its first real boot;
that remains part of the QEMU and hardware test contracts in [Simple Test Evidence](base-system.md).

### Tradeoffs

- The user can cancel freely before data loss and receives a distinct warning
  for emergency stopping afterward.
- UI failure does not abandon a privileged disk operation or create a second
  transaction.
- Durable checkpoints permit conservative continuation without storing
  credentials in transaction state.
- Some interrupted storage work is restarted rather than resumed at a finer
  granularity, which is simpler and safer but may take longer.
- Backend-declared retryability avoids both blind retry loops and an arbitrary
  fixed attempt count.
- Success is stronger than command completion but does not overclaim evidence
  of an actual first boot.

### Ownership boundaries

This section owns installer phases, the destructive boundary, cancellation and
controlled stop behavior, durable checkpoints, resume, retry, failure, and
completion verification. [Minimal Installer Protocol](installer.md) owns message and event envelopes. [One-Shot Installer Secret Channel](#one-shot-installer-secret-channel)
owns secret lifetime. [Installer Disk Identity and Confirmation](#installer-disk-identity-and-confirmation) owns disk identity and final destructive
confirmation. [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md) owns Recovery Kit presentation after the credentials
have been enrolled and tested.
