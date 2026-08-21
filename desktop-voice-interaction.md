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

Ordinary Assistant responses are spoken through local text-to-speech by
default. A per-user setting may also show them temporarily as floating assistant
bubbles, but that presentation is disabled initially. Generated response text
is discarded after speech by default unless it contributes to a logged action
or derived memory.

While speech output is active, the system bar shows an indicator. Clicking it
stops speech immediately without undoing completed actions. Pressing
push-to-talk also stops current speech and begins a new capture immediately.
Other playing audio is ducked rather than paused during assistant speech and
restored afterward. This default is configurable per user.
When a voice Assistant request is queued behind existing work, ShapeBit plays a
short local acknowledgement sound and updates the assistant queue count instead
of speaking a full status message.
Locking the session stops assistant speech immediately. No assistant speech or
visual output appears on the lock screen; results from continuing authorized
work become available only after unlock.

If a voice Assistant request needs capability permission or action
confirmation, the assistant bubble overlay presents the same structured card as
chat even when ordinary response bubbles are disabled. This does not create a
persistent chat conversation or retain the voice transcript. The resulting
action event remains in the central assistant activity log.

## Deferred details

The exact default push-to-talk control will be selected later.
