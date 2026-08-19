# ADR-0037: Installer Transaction Lifecycle

**Status:** Accepted

**Date:** 2026-08-13

## Context

Once the installer starts erasing the selected disk, closing the UI, losing
power, or retrying an unsafe step must not create a second uncontrolled
operation or a false success result. The initial lifecycle needs understandable
phases, one explicit destructive boundary, durable progress without secrets,
and conservative recovery rather than a general rollback mechanism.

## Decision

### Installation phases

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

### Destructive boundary and stopping

`validating` and `preparing` are non-destructive and expose ordinary **Cancel**.
ADR-0038's final disk confirmation authorizes one transition into
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
unneeded secret requests and plaintext according to ADR-0036.

### Durable transaction journal and checkpoints

Before the destructive boundary, transaction state is temporary because the
target has not changed and the plan can be started again. After the boundary,
the target disk carries a small durable, secret-free installation journal. The
backend establishes its durable location as early as the storage layout safely
allows and synchronizes it after every completed checkpoint.

The journal records only:

- transaction and protocol identifiers;
- target release digest;
- the ADR-0038 target-disk identity;
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
can only be started again after ADR-0038 confirmation.

### Resume and start over

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

### Waiting, failure, and retry

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

### Verification and completion

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

After every verification succeeds, ADR-0039's presentation gate requires the
current Recovery Kit to be presented and acknowledged. Only then does the
backend durably write an installation-complete marker, emit the terminal
`completed` result, and remove the resumable transaction journal. If
interruption occurs between those actions, the complete marker takes precedence
and permits safe cleanup of the stale journal.

Installer completion means that required disk state was verified. It is not
evidence that the particular physical computer completed its first real boot;
that remains part of the QEMU and hardware test contracts in ADR-0033.

## Consequences

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

## Boundaries

This ADR owns installer phases, the destructive boundary, cancellation and
controlled stop behavior, durable checkpoints, resume, retry, failure, and
completion verification. ADR-0035 owns message and event envelopes. ADR-0036
owns secret lifetime. ADR-0038 owns disk identity and final destructive
confirmation. ADR-0039 owns Recovery Kit presentation after the credentials
have been enrolled and tested.

## Related decisions

- [ADR-0003](ADR-0003-btrfs-system-state.md)
- [ADR-0010](ADR-0010-dioxus-installer.md)
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0012](ADR-0012-encrypted-system-volume.md)
- [ADR-0016](ADR-0016-initial-installation-and-storage-profile.md)
- [ADR-0033](ADR-0033-simple-test-evidence.md)
- [ADR-0035](ADR-0035-minimal-installer-protocol.md)
- [ADR-0036](ADR-0036-one-shot-installer-secret-channel.md)
- [ADR-0038](ADR-0038-installer-disk-identity-and-confirmation.md)
- [ADR-0039](ADR-0039-recovery-kit-presentation-and-lifecycle.md)
