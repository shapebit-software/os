# Gaze Input

**Status:** Draft

Gaze input is an optional way to position the pointer at the place where the
user is looking. This document records intended behavior, not implemented or
verified desktop behavior.

## Activation

- Gaze input is enabled by default for each user and can be disabled.
- Looking alone never moves the pointer or activates an interface element.
- An explicit keyboard key or mouse button moves the pointer to the latest
  stable gaze point without clicking. ShapeBit provides a default trigger that
  the user can reconfigure.
- With a reliable point, the trigger moves the pointer immediately and shows a
  brief visual ripple at the destination so it is easy to locate.
- The destination is the measured gaze point; ShapeBit does not snap to nearby
  controls by default.
- The trigger does nothing during an active pointer drag or resize, preventing
  an object from being moved unexpectedly.
- The system bar shows a privacy indicator whenever tracking is active. The
  indicator provides direct pause and resume controls.

## Data boundary

- Camera frames and derived gaze data remain local and transient. Only the
  latest stable gaze point is held in memory.
- Applications and agents cannot access frames, gaze data, or that point.
- Tracking stops on the login screen, lock screen, and authentication prompts,
  and resumes only in the unlocked user session.

Camera access and privacy indication remain subject to
[ADR-0020](adr-0020-media-privacy-and-notifications.md).

## Calibration and reliability

- First login with supported hardware offers guided calibration. It may be
  skipped, but tracking remains paused until calibration succeeds.
- Without supported gaze hardware, the feature remains inactive without
  repeated prompts or error indicators. Settings shows that it is unavailable.
- If the trigger is pressed without a reliable point, the pointer remains in
  place and a brief recalibration notice appears.
- Sustained low confidence pauses tracking and offers recalibration instead of
  repeatedly showing notices.
- Calibration is stored separately for each display, and the pointer may move
  directly between calibrated displays. Looking at an uncalibrated display does
  not move the pointer and offers calibration instead.
- A display-position, orientation, scaling, or physical-setup change that makes
  stored calibration unreliable pauses tracking for that display until it is
  recalibrated.

## Deferred details

The exact default binding, stability and confidence thresholds, and detailed
recalibration flow will be selected later.
