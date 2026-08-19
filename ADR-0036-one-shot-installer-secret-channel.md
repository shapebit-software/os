# ADR-0036: One-Shot Installer Secret Channel

**Status:** Accepted

**Date:** 2026-08-12

## Context

ADR-0035 keeps passwords, Wi-Fi credentials, recovery keys, and derived secrets
out of the serializable installation plan and ordinary JSON Lines protocol. The
installer still needs a small local mechanism to transfer user-entered secrets
to the privileged backend and generated Recovery Kit material in the opposite
direction without temporary files, environment variables, event history, or
diagnostic capture.

## Decision

### One-shot channel

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

### Direction and purpose

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

### Binary framing and limits

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

### Input ownership and lifetime

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
disk. ADR-0037 determines whether the transaction can wait safely for a
replacement, must stop, or must continue through recovery.

### Recovery Kit output

After the backend generates and enrolls the independent device and first-home
recovery keys, it transfers their presentation package through one
`output/recovery-kit` request. The package preserves the distinction between the
two keys even when ADR-0039 presents them as one logical Recovery Kit.

The frontend retains the package only for the trusted presentation flow and
zeroizes it after that flow ends. If the frontend loses the package before
presentation is acknowledged, the backend does not silently rotate or generate
new enrolled keys. It may issue another one-shot output request for the same
temporarily retained keys. Unlike unused input, these already-enrolled output
keys survive a frontend reconnect while the backend remains alive, as defined
by ADR-0039. A backend restart before acknowledgement invokes ADR-0039's safe
key replacement instead of restoring plaintext from persistent state.

### Owner-password confirmation

The frontend asks for the owner password twice and compares the two fields
locally. It transfers one copy only after they match. The backend validates the
single received value against the accepted encoding, length, and password
policy; it does not receive a confirmation copy.

Paste, password managers, and an explicit temporary reveal action remain
available. Leaving the screen or successful transfer clears both fields and
their backing buffers on a best-effort basis. A backend rejection requires the
user to enter and confirm the password again. Wi-Fi passwords are entered once.

## Consequences

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
  reconnects; ADR-0039 closes that lifecycle and defines safe replacement after
  a backend restart.

## Boundaries

This ADR owns the installer secret transport, direction and purpose binding,
framing, initial size and expiry limits, input ownership and lifetime,
cancellation, and local password confirmation. ADR-0010 owns the installer
privilege boundary. ADR-0035 owns ordinary messages. ADR-0037 owns transaction
waiting and interruption. ADR-0039 owns Recovery Kit presentation and final
secret lifetime.

## Related decisions

- [ADR-0010](ADR-0010-dioxus-installer.md)
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0012](ADR-0012-encrypted-system-volume.md)
- [ADR-0035](ADR-0035-minimal-installer-protocol.md)
- [ADR-0037](ADR-0037-installer-transaction-lifecycle.md)
- [ADR-0039](ADR-0039-recovery-kit-presentation-and-lifecycle.md)
