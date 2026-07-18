# ADR 0003: Settings live on the back face of the status popover (a flip)

- Status: Accepted
- Date: 2026-07-18

## Context

Clicking the menu bar icon opens a single transient `NSPopover` whose SwiftUI
`PanelView` stacked two very different things in one 340-pt column:

1. **A status readout** — the header, the CPU/GPU live rings, the memory donut,
   and the 3-minute history chart. This is what a user opens the popover *for*: a
   glance at "how busy is it right now."
2. **The full settings surface** — display mode, color mode, per-source shape and
   color swatches, the label toggle, the whole memory block (menu-bar visibility,
   frame, color mode), and launch-at-login.

The two coexisted acceptably when settings were small, but ADR 0002 added a full
memory settings block (toggle + shape + color mode + swatch/gradient row). The
settings half now outweighs the status half, and the glanceable readout a user
opens the popover to see is pushed up by a dense wall of controls below a divider.
The popover reads as a settings sheet with a status header, not a status view.

Settings are also *rarely* touched — set once, revisited occasionally — whereas
the status is looked at constantly. Paying for the settings' vertical weight on
every glance is the wrong trade.

## Decision

Split the popover into two **faces of one card** and flip between them, keeping
everything anchored under the menu bar icon.

- **Front = status, back = settings.** `PanelView` (front) keeps the header, live
  rings, memory donut, and history chart — no controls. A new `SettingsView` (back)
  holds everything previously under the divider, reorganized into three labeled
  sections: **インジケーター** (mode, color mode, per-source rows, label toggle),
  **メモリ** (the ADR-0002 memory block), and **全般** (launch at login).
- **A `PanelContainer` owns the flip.** It hosts both faces in a `ZStack`, applies a
  Y-axis `rotation3DEffect` (0° ⇄ 180°, `perspective` 0.35), and pre-rotates the
  back face 180° so it reads correctly at the end of the turn. Each face's opacity
  crossfades on a half-duration schedule (front out in the first half, back in after
  the midpoint) so the two are never both visible mid-flip and no face is ever seen
  mirrored.
- **Both toggles sit in the top-right corner.** The front's gear (`gearshape`) and
  the back's chevron (`chevron.backward`) occupy the *same* corner, so the flip
  control never moves under the cursor. Both are `.focusable(false)` — otherwise the
  chevron grabs keyboard focus and draws a focus ring the instant the settings face
  appears.
- **The popover height fits the visible face.** The status face is shorter than
  settings; rather than pad it out to the taller face, the container measures each
  face's *natural* height (`.fixedSize(vertical:)` + a `GeometryReader`/
  `PreferenceKey`, so the measurement is independent of the height the container is
  currently constrained to) and animates `.frame(height:)` between the two in step
  with the rotation. The inactive, taller face overflows the frame but is hidden.
- **Always opens to the status face.** The popover's `NSHostingController` is still
  built lazily on open and released on close (ADR 0002's lazy-hosting note), so the
  flip `@State` resets to the front every time it opens.
- **The model is shared.** Both faces observe the same `AppModel`; changing a
  setting on the back restyles the front (and the menu bar) live. Only the controls'
  *location* changed, not their behavior.

## Consequences

- `PanelView` shrinks to the status readout plus a gear (header) / quit (footer),
  and drops all settings-only helpers (bindings, config rows, swatches, gradient
  previews). Those move verbatim into `SettingsView`, so no settings *behavior*
  changed — this is a relocation, not a redesign of the controls.
- `AppDelegate` keeps a single popover; there is **no** window lifecycle, activation
  policy juggling, or second surface to manage. The app stays a dock-less accessory.
- Both faces are built each time the popover opens (the container holds both for the
  flip). `SettingsView` is static — no timers, no animation — so building it is
  cheap; the only continuously-updating view remains the front's static gauges and
  chart, unchanged from ADR 0002.
- Per-face height measurement means the popover resizes as the *content* of a face
  changes too (e.g. switching display mode adds/removes a config row), not just on
  the flip — the frame tracks the measured height either way.
- No `LoadSpinnerCore` logic changed, so the pure-function test suite is unaffected
  (still green). The split is presentation only, a layer this project deliberately
  keeps thin and does not unit test.

## Alternatives considered

- **A separate settings `NSWindow` (opened from a gear button).** Built and tried
  first. It is the conventional macOS "Settings…" home and keeps the popover
  trivially simple, but in use it felt *disjoint*: clicking the gear dismissed the
  transient popover and a window appeared elsewhere on screen (centered, away from
  the menu bar), and — being an accessory app — it had to `NSApp.activate` and dim
  the frontmost app to take focus. The eye and cursor jump broke the "I'm glancing at
  my menu bar" flow. The flip keeps everything under the icon and reads as one object
  turned over, which is what we wanted.
- **Tabbed popover (a segmented 情報 / 設定 switch at the top).** Keeps one surface
  but still crowds a 340-pt column and adds chrome; a flip conveys the
  front/back relationship more directly and needs no persistent tab bar.
- **A second popover off the gear button.** Two `.transient` popovers interact
  badly — opening one dismisses the other — making the open/close dance fiddly.
- **A fixed card size (both faces padded to the taller).** Simpler (no height
  measurement), and truer to a physical card, but it padded the status face with
  dead space to match the settings height. Fitting each face won out; the flip is
  already a loose-enough card metaphor to allow the size to change.
