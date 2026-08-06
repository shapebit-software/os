# Installer UI

The Dioxus frontend collects installation choices, submits typed requests from
the shared protocol, and displays progress and errors. It must not execute
privileged operations or pass arbitrary commands to the backend.

The first integration uses a mock backend before any real-disk workflow.

User creation collects the login password once and explains that it also
unlocks the encrypted home. The UI passes it through the secret-enrollment
channel and must never include it in `InstallationPlan`, logs, or diagnostics.

## Recovery Kit

The initial device owner saves one logical ShapeBit Recovery Kit containing:

- the device recovery key for the system LUKS2 volume;
- the initial owner's home recovery key for that user's LUKS2 home.

The keys remain independent. Combining them in one presentation must not reuse
one key, derive one from the other, or make the device key capable of unlocking
the user's home.

The installer uses one recovery screen:

1. Explain that anyone holding the Recovery Kit can access the corresponding
   encrypted volumes and that ShapeBit cannot restore a lost kit.
2. Display one QR code containing a versioned, clearly labeled representation
   of both recovery keys.
3. Keep the grouped plain-text representation hidden until the user selects
   **Show text**.
4. Offer copy, print, and removable-media export for the complete kit.
5. Require a simple **I saved my Recovery Kit** acknowledgement. Do not require
   the user to retype or verify selected key fragments.
6. Clear the QR payload, revealed text, clipboard data where supported, and
   other in-memory UI state when the screen is left.

The QR code is itself a representation of both secrets and must receive the
same screen-capture, logging, analytics, and lifetime protections as revealed
plain text. Export must not target the system volume being protected, and the
UI must warn against keeping removable media or a printout with the device.

An additional user receives a separate kit containing only that user's home
recovery key. The device recovery key is not shown during additional-user
creation.

The installer shows newly generated recovery keys once. A later settings flow
offers **Replace recovery key**, not **Show existing recovery key**: it creates
and verifies a new keyslot before revoking the old one.
