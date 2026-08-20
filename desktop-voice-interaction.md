# Voice Interaction

**Status:** Draft

Voice interaction lets the user work with ShapeBit through local AI agents.
This document records intended behavior, not implemented or verified desktop
behavior.

## Capture and privacy

- Voice interaction is push-to-talk only; there is no always-listening mode.
- Capture begins only after the explicit push-to-talk action and stops when the
  interaction ends.
- ShapeBit provides a default push-to-talk key or button that the user can
  reconfigure.
- The system bar shows a microphone indicator during capture. Clicking it
  immediately cancels the interaction.
- Speech recognition and agent processing run locally. Audio, transcripts, and
  agent requests are never sent to cloud services.
- Captured audio and transcripts are discarded after each interaction by
  default.
- All modes are unavailable on the login screen, lock screen, and
  authentication prompts.

Microphone access and privacy indication remain subject to
[ADR-0020](adr-0020-media-privacy-and-notifications.md).

## Modes

- **Assistant:** Sends the utterance to a local agent as a request.
- **Speech to text:** Inserts a local transcription into the focused text
  input.
- **Speech to text with translation:** Translates the local transcription and
  inserts it into the focused text input. The current input language is the
  default translation target.
- The mode is explicitly selected, visibly indicated, and remembered per user;
  it is never inferred from speech. **Assistant** is the initial mode for a new
  user.

Assistant mode uses the shared
[assistant framework](desktop-assistant-framework.md)
also used by chat interaction.

## Deferred details

The exact default push-to-talk control will be selected later.
