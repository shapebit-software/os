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
2. Display one QR code containing the complete versioned offline representation
   of both recovery keys; it must not contain a URL or server reference.
3. Keep the grouped plain-text representation hidden until the user selects
   **Show text**.
4. Offer printing and password-encrypted export to another attached storage
   device. The export password is entered twice and is separate from the owner
   password; successful export is read back and decrypted before it is called
   verified.
5. Require the user to use encrypted export, print, or QR/text display and then
   select **I saved my Recovery Kit outside this computer**. Do not require the
   user to retype or verify selected key fragments, and do not call print or
   manual saving a verified backup.
6. Clear the QR payload, revealed text, and other in-memory UI state when the
   presentation ends and no later than five minutes after the screen closes.

The QR code is itself a representation of both secrets and must receive the
same screen-capture, logging, analytics, and lifetime protections as revealed
plain text. Recovery material is hidden during screen sharing and on session
lock, and the initial flow does not offer clipboard copying. Export must not
target the system volume being protected, and the UI must warn against keeping
removable media or a printout with the device.

The backend may re-present the same kit after a UI restart while it remains
alive. If the backend restarts before acknowledgement, the UI asks for the
owner password again, clearly invalidates every earlier unconfirmed copy, and
presents the safely replaced keys as a new kit. Installation cannot report
completion until the current kit has been acknowledged.

An additional user receives a separate kit containing only that user's home
recovery key. The device recovery key is not shown during additional-user
creation.

The installer shows newly generated recovery keys once. A later settings flow
offers **Replace recovery key**, not **Show existing recovery key**: it creates
and verifies a new keyslot before revoking the old one.
