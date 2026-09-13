Trial Boot and Rollback

A newly staged deployment starts as pending.

Booting it changes it to trial.

ShapeBit uses systemd Automatic Boot Assessment for attempt counting and boot selection rather than maintaining a second authoritative boot database.

The default limit is two trial attempts.

accepted
   ↓
pending
   ↓
trial
 ┌─┴────────────┐
 ↓              ↓
accepted       failed
                ↓
             rollback

The previous accepted deployment remains available until the new deployment is durably accepted.

A deterministic integrity or structural failure causes immediate rollback.

An ambiguous failure consumes a trial attempt. When attempts are exhausted, systemd-boot selects the previous accepted deployment.

A failed release is locally blocked from automatic restaging until another release supersedes it or recovery explicitly retries it.

Boot Health

A trial deployment is accepted only when ShapeBit verifies:

expected release and deployment identity;
required system storage;
critical platform services;
functioning network stack;
usable graphical login environment.

Internet connectivity and user login are not required.

All mandatory checks must succeed and remain healthy for a short continuous observation period before the deployment is blessed.

Exact units, service lists, timeouts, retry periods, and diagnostic codes are implementation policy rather than architecture.