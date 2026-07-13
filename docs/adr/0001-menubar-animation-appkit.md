# ADR 0001: Menu bar animation uses AppKit NSStatusItem, not SwiftUI MenuBarExtra

- Status: Accepted
- Date: 2026-07-13

## Context

The core value of load-spinner is a menu bar indicator that animates smoothly and
continuously, at a speed proportional to system load. The RFP initially assumed a
SwiftUI `MenuBarExtra(.window)` app.

`MenuBarExtra`'s label content is rendered to a static image and refreshed only on
state change. It is not designed for continuous per-frame animation; driving it at
~30 fps by mutating state is both janky and wasteful, and fights the framework.

## Decision

Use an AppKit `NSStatusItem` whose button hosts a layer-backed `NSView`
(`SpinnerView`). The indicator is drawn with `CAShapeLayer`s: a fixed track plus a
highlight whose `lineDashPattern` defines one lit segment. Animating
`lineDashPhase` moves that segment around the fixed perimeter — matching the spec
that "the frame stays fixed and the color travels," for both circle and rounded
square. A lightweight timer advances the phase; rotation speed is set by the
load→RPM mapping in `LoadSpinnerCore`.

The click-to-open panel (Phase 2) will still be built in SwiftUI and hosted via
`NSHostingView` inside an `NSPopover`/`NSWindow`, so we keep SwiftUI where it is
strong (declarative panel UI, Swift Charts) and AppKit where it is necessary
(reliable menu bar animation).

## Consequences

- Full control over smooth animation and self-imposed low CPU cost (observed ~0.3%).
- A small amount of AppKit boilerplate (status item, menu) instead of a pure
  SwiftUI `App`.
- The animated view lives for the whole app lifetime (single status item), which
  is why it intentionally has no timer teardown in `deinit` (also avoids a Swift 6
  main-actor-isolated `deinit` restriction).
- Hybrid AppKit + SwiftUI is a well-trodden pattern for menu bar apps and does not
  block the Phase 2 panel work.
