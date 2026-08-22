# Desktop Technical Design

This document evaluates and records concrete implementation choices for
ShapeBit Desktop. It complements the technology-independent rules and
boundaries in [Desktop Environment](desktop.md); it does not override them.

The choices in this document are proposed unless they are explicitly marked as
accepted. They are not implementation evidence.

## Scope

This document owns:

- programming-language choices for desktop components;
- UI toolkit and language-binding choices;
- compositor and shell implementation libraries;
- private desktop protocol and state-model design;
- dependency, compatibility, and development-workflow policy; and
- technical validation required before implementation choices are accepted.

The architecture remains authoritative for process separation, privilege,
trusted surfaces, session lifecycle, display policy, media privacy, and
application boundaries. Exact dependency versions and verified behavior belong
to component manifests, source repositories, tests, and runtime evidence.

## Architecture constraints

The technical design must preserve these existing constraints:

- the compositor owns Wayland objects, outputs, input, and authoritative lock
  state;
- the shell is a separate, unprivileged process that can restart without
  terminating applications or unlocking the session;
- the greeter, lock UI, and authorization agent are separate trusted
  processes;
- privileged operations remain in narrow system services exposed through
  versioned D-Bus interfaces; and
- ordinary native Wayland applications work without ShapeBit-specific client
  support.

See [Desktop Session and Authorization Boundaries](desktop.md#desktop-session-and-authorization-boundaries)
for the owning architecture.

## Desktop communication boundary

**Status: Accepted.**

Compositor-owned live graphical state and actions use Wayland protocols. This
includes outputs and seats, toplevel windows, Workspaces and layouts, focus and
activation, window arrangement, shell surface roles, input-serial-dependent
interactions, and trusted-surface coordination. Standard Wayland protocols are
used when their semantics fit; private ShapeBit protocols cover only missing
desktop behavior.

Services that exist independently of the compositor use versioned D-Bus APIs.
This includes power, networking, updates, accounts, persisted settings,
diagnostics, privileged operations, and long-running jobs.

Each state has one authoritative owner. A compositor-owned state such as the
active Workspace is not exposed through a competing D-Bus state model. The
shell may combine Wayland and D-Bus data for presentation, but it does not
become the authority for either source.

This decision selects the transport boundary. It does not yet define private
Wayland protocol families, messages, access control, version negotiation, or
shell reconnection behavior.

## Component technology map

| Component | Current direction | Status |
| --- | --- | --- |
| Compositor | Rust with Smithay | Accepted design; not implemented or validated |
| Shell | Rust with GTK 4 through gtk-rs | Accepted design; not implemented or validated |
| Greeter | Rust with GTK 4 through gtk-rs | Accepted design; not implemented or validated |
| Lock UI | Rust with GTK 4 through gtk-rs | Accepted design; not implemented or validated |
| Authorization agent | Rust with GTK 4 through gtk-rs | Accepted design; not implemented or validated |
| Settings | Rust with GTK 4 through gtk-rs | Accepted design; not implemented or validated |
| First-party graphical applications | Rust with GTK 4 through gtk-rs by default | Accepted design; exceptions require a technical decision |
| Privileged platform services | Rust is the leading candidate | Proposed |
| Installer frontend | Rust with GTK 4 through gtk-rs | Accepted design; not implemented or validated |

The installer remains outside the desktop component set and retains a separate
privileged backend. Its frontend uses the same graphical technology baseline so
that ShapeBit does not maintain a second first-party UI stack.

## Compositor foundation

Smithay is not the only library capable of supporting the ShapeBit compositor.
The foundation was selected independently from the shell UI toolkit and must
preserve the architecture's minimal-compositor and restartable-shell boundary.

### Decision

**Status: Accepted.**

ShapeBit will implement its compositor in Rust using Smithay. Smithay supplies
the Wayland, input, output, rendering, and hardware-backend building blocks;
ShapeBit owns desktop policy, layout, trusted lock state, private protocols, and
the boundary with the separately restartable shell.

This decision does not select the shell UI toolkit or require every desktop
process to use Rust. It also does not establish that the compositor has been
implemented or validated.

### Requirements

The compositor foundation must provide or permit:

- nested development and direct DRM/KMS operation;
- multiple outputs, hotplug, mixed scaling, and independent refresh rates;
- libinput, keyboard-layout, touch, pen, gesture, and input-method integration;
- hardware and software rendering paths;
- DMA-BUF, explicit synchronization, direct scan-out, and screen-capture
  integration where supported;
- standard Wayland protocols plus private versioned ShapeBit protocols;
- compositor-owned tiling, stacks, collapsed regions, Workspaces, Overview
  state, and authoritative session locking;
- a separately restartable shell rather than an inseparable in-process desktop
  UI; and
- practical automated protocol, rendering, nested-session, and hardware tests.

### Candidates

| Foundation | Language | Strengths | Principal concerns | ShapeBit assessment |
| --- | --- | --- | --- | --- |
| [Smithay](https://github.com/Smithay/smithay) | Rust | Modular Rust-native Wayland, input, output, backend, and rendering building blocks; used by complete desktop compositors | It is not a complete compositor; API evolution and incomplete protocols may require ShapeBit work | Selected |
| [wlroots](https://wlroots.pages.freedesktop.org/wlroots/) | C | Broad compositor ecosystem, modular backends, protocol implementations, renderer abstraction, and XWayland support | New ShapeBit policy would be implemented across a C API or a maintained Rust FFI boundary; API migrations remain an ownership cost | Strong low-level alternative |
| [MirAL](https://canonical.com/mir/docs/stable/reference/introducing_the_miral_api/) | C++ | Higher-level compositor construction, stable public ABI, window-management policy interface, custom extensions, and existing desktop and device deployments | Introduces C++ and a larger, more opinionated framework below ShapeBit policy | Strongest high-level alternative |
| [libweston](https://wayland.pages.freedesktop.org/weston/toc/libweston.html) | C | Correctness-oriented Weston core, hardware backends, protocol implementation, and extensive compositor tests | Its own documentation still describes the public API and feature set as evolving toward stability and completeness | Not preferred initially |
| [Qt Wayland Compositor](https://doc.qt.io/qt-6/qtwaylandcompositor-index.html) | C++ and QML | High-level custom compositor APIs tightly integrated with Qt Quick animation and rendering | Primarily positioned for embedded application-manager systems; couples compositor choices to Qt and uses commercial or GPLv3 licensing | Consider only with a Qt-wide desktop direction |
| [Louvre](https://github.com/CuarzoSoftware/Louvre) | C++ | High-level defaults that can be overridden gradually and a relatively direct path to a working compositor | Smaller deployment base and several desktop capabilities remain incomplete | Watch, not shortlist |

KWin and Mutter are mature compositors but are not preferred foundations for a
new ShapeBit compositor. Their implementation and extension models are closely
tied to KDE Plasma and GNOME Shell respectively, making reuse closer to adopting
or maintaining a downstream desktop stack than using a neutral compositor
library.

### Rationale and alternatives

Smithay matches the Rust language direction, permits ShapeBit to own its
unusual Workspace and layout model, and does not require the shell UI to run
inside the compositor.

MirAL remains the principal high-level alternative. wlroots remains the
reference low-level alternative when C ownership and API migration are
acceptable. They are not selected because their potential reduction in
framework work does not outweigh the additional C++ or C ownership and language
boundary for the current ShapeBit direction.

Implementation begins with a source-level Smithay capability and maintenance
audit against every required protocol and hardware path, followed by a nested
prototype. Missing upstream functionality becomes explicit ShapeBit work or an
upstream contribution; it must not be silently treated as available.

Revisit the foundation only if Smithay cannot meet a mandatory security,
protocol, rendering, hardware, or maintainability requirement within acceptable
project cost. A revisit must compare current evidence against MirAL and wlroots
rather than assuming the original comparison remains current.

## Programming language

### Requirements

The primary desktop language should provide:

- memory safety for long-running, input-facing and protocol-facing processes;
- predictable performance without a mandatory garbage-collected runtime;
- strong support for Wayland and the selected compositor library;
- maintainable asynchronous I/O and D-Bus integration;
- usable bindings for required Linux system libraries;
- clear isolation and review of unavoidable unsafe foreign-function calls;
- reproducible dependency resolution; and
- practical debugging, profiling, testing, and packaging in the ShapeBit
  image.

### Rust assessment

Rust is a strong primary-language candidate for ShapeBit Desktop.

Its strongest fit is the compositor. [Smithay](https://github.com/Smithay/smithay)
provides Rust building blocks for Wayland compositors, including protocol,
input, output, rendering, and backend integration. Using Rust for the
compositor avoids introducing a language boundary around the component that
owns the most complex desktop state.

Rust is also a strong fit for platform services, private protocol models,
persistent-state handling, and other long-running processes. Its ownership and
type systems prevent broad classes of memory and concurrency errors, while
FFI remains available for Linux libraries without native Rust APIs. Unsafe code
must be kept behind small safe abstractions and reviewed separately.

For graphical processes, the answer depends on the UI toolkit:

- GTK 4 has maintained safe Rust bindings through
  [gtk-rs](https://gtk-rs.org/gtk4-rs/stable/latest/docs/gtk4/), making Rust a
  natural choice for a GTK-based shell and first-party applications.
- Qt Quick is designed primarily around QML and C++. Requiring Rust for its UI
  backend would add a binding and tooling risk that must be justified by a
  prototype.
- Flutter uses Dart for interface code. Selecting Flutter would therefore make
  a Rust-only desktop policy impractical even if native services remained in
  Rust.

Rust does not remove native-library risk. The compositor, graphics stack,
input stack, GTK, PAM, Polkit, PipeWire, and other dependencies still contain C
or C++ code. Rust reduces the amount of new memory-unsafe code owned by
ShapeBit; it does not make the complete process memory-safe.

### Preliminary recommendation

The compositor and graphical-component language decisions are accepted:
ShapeBit uses Rust for the Smithay compositor and Rust with gtk-rs for GTK 4
graphical components. The broader proposed direction is:

- use Rust as the default language for the compositor, desktop protocols,
  persistent desktop state, and ShapeBit platform services;
- use Rust with GTK 4 through gtk-rs for the shell, greeter, lock UI,
  authorization agent, Settings, installer frontend, and first-party graphical
  applications by default;
- do not require Rust where it would force an immature binding over a toolkit's
  established native programming model; and
- isolate unavoidable C ABI integration in small modules with safe Rust-facing
  interfaces.

Rust remains proposed rather than accepted for privileged platform services
and non-graphical components not listed above.

### Risks and costs

- Smithay supplies compositor building blocks rather than a complete desktop;
  ShapeBit must own policy, protocol composition, layout, recovery, and
  hardware validation.
- Some Linux integration crates and language bindings evolve faster than the
  underlying system libraries and may require source migrations.
- Rust compile times and complex generic errors can slow early iteration.
- GTK and other event-loop-based libraries impose threading rules that Rust's
  type system does not eliminate.
- FFI and graphics-driver boundaries remain capable of memory-safety and
  process-stability failures.
- A strict single-language rule could produce worse integrations than a small,
  well-contained component written in its ecosystem's native language.

### Validation before acceptance

Accepting Rust as the desktop language baseline requires evidence from small
technical prototypes:

1. Run a nested Smithay compositor with output, pointer, keyboard, touch,
   clipboard, drag-and-drop, text-input, and session-lock protocol exercises.
2. Implement the radial-menu interaction in the selected GTK 4 and gtk-rs stack,
   including keyboard navigation, screen-reader semantics, text scaling, high
   contrast, and reduced motion.
3. Restart the shell while clients remain connected, then restore its state
   through a versioned compositor handshake.
4. Implement one asynchronous versioned D-Bus service and client with caller
   identity, cancellation, timeout, and structured-error tests.
5. Exercise PAM and Polkit integration in isolated trusted-process prototypes
   without placing secrets in logs, diagnostics, or crash reports.
6. Record build time, startup time, memory use, frame pacing, software-renderer
   fallback, and failure behavior in the supported VM profile.
7. Inventory all unsafe blocks and native ABI boundaries and confirm that each
   has an explicit safety contract and focused tests.

Documentation or successful compilation alone does not satisfy these gates.

## UI toolkit

### Decision

**Status: Accepted for first-party graphical components.**

The ShapeBit shell, greeter, lock UI, authorization agent, Settings, installer
frontend, and first-party graphical applications will be written in Rust and
use GTK 4 through gtk-rs by default. An exception requires a separate technical
decision. Each component retains its architecture-defined process, privilege,
and trust boundary.

The shell runs as a separate unprivileged Wayland client of the Smithay
compositor. GTK owns widget construction, accessibility semantics, input
handling, text, layout, and application-side rendering. ShapeBit owns component
behavior, custom components, visual styling, and communication with the
compositor and platform services.

The shell may use GTK CSS, GSK, and custom GTK widgets where ordinary widgets
cannot express ShapeBit interactions such as radial menus or Overview. This
decision does not select libadwaita and does not require ShapeBit to adopt GNOME
application design conventions.

The installer frontend remains unprivileged and communicates with its separate
privileged backend through the installer protocol. Selecting one UI toolkit
does not merge component processes, privileges, release gates, or security
responsibilities.

### Rationale and alternatives

GTK 4 and gtk-rs align the shell with the Rust compositor and service direction
while retaining a mature Linux-native toolkit, accessibility integration,
Wayland support, input methods, text rendering, and a software-rendering path.
The binding keeps most shell code memory-safe while retaining access to the
underlying GTK, GDK, GSK, Cairo, Pango, Gio, and GLib APIs.

Qt Quick offered stronger built-in emphasis on fluid custom animation, but it
would introduce QML and C++ into the core shell and complicate the Rust language
boundary. Slint remains less proven for a complete Linux desktop shell. Flutter
would introduce Dart and a larger rendering runtime, while its standard Linux
embedding adds another native integration layer. These alternatives remain
revisit options rather than selected dependencies.

### Boundaries and compatibility

- The compositor does not link GTK and remains operable when the GTK shell
  exits or fails.
- Private shell authority is granted through authenticated, versioned Wayland
  and D-Bus contracts rather than by GTK process identity alone.
- The shell must not depend on GTK private APIs or undocumented widget
  internals.
- The ShapeBit image pins a supported GTK 4 feature baseline and compatible
  gtk-rs release. Exact versions belong to manifests and verified build
  evidence, not this design document.
- GTK and gtk-rs upgrades are deliberate platform changes with build,
  accessibility, rendering, protocol, and restart regression tests.
- A future GTK major version is not adopted automatically.

### Validation

The implementation must validate:

- Wayland and private-protocol integration;
- accessibility on Linux;
- custom components, rendering, and animation;
- keyboard, pointer, touch, pen, and input-method support;
- shell restart and state restoration;
- shell process attack surface and protocol boundaries;
- dependency and major-version compatibility policy;
- image size, startup time, memory use, and software fallback; and
- development iteration, debugging, and profiling.

The first UI prototype must exercise the radial menu, one per-output system
bar, a small live Overview, custom compositor surface roles, keyboard-only and
screen-reader operation, text scaling, high contrast, reduced motion, shell
termination and restart, and both accelerated and software rendering.

## Component naming

**Status: Accepted.**

ShapeBit-owned components use concise role names without a `shapebit-` prefix.
This applies to workspace directories, internal crate names, installed
executables, and component service units. Examples include `compositor`,
`shell`, `greeter`, `lock`, `authorization-agent`, `settings`, and `installer`,
not `shapebit-compositor`, `shapebit-shell`, or `shapebit-settings`.

Names in global or cross-vendor namespaces remain explicitly namespaced where
the platform requires uniqueness or uses the name as a security boundary. This
includes D-Bus well-known names and interfaces, desktop application IDs,
Flatpak IDs, Polkit action IDs, MIME types, and public protocol identifiers.
Those identifiers use the appropriate reverse-domain ShapeBit namespace rather
than an unqualified role name.

Product labels remain user-facing names such as **Settings** or **ShapeBit
Installer** and are independent from executable and protocol identifiers.

## Open decisions

1. Define the private Wayland protocol families, access control, versioning,
   and shell reconnection contract.
2. Define the persistent Workspace and window-layout state model.
3. Define the dependency baseline and upgrade policy for desktop crates and
   native libraries.
