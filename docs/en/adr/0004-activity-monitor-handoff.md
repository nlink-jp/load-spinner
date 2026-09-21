# ADR 0004: Hand off to Activity Monitor from the panel footer

- Status: Accepted
- Date: 2026-08-23

## Context

The menu bar indicator answers one question — *how busy is this machine right
now* — and answers it deliberately without numbers (ADR 0001). Clicking it opens
the status panel, which answers the same question with a little more precision:
live CPU/GPU percentages, memory used, and three minutes of history.

The question that follows is always the same one, and this app cannot answer it:
**busy with what?** Naming the process means a process table, per-process
sampling, sorting, and a way to act on a row — which is Activity Monitor, an app
that already ships with the OS, is already familiar, and is already where the user
was headed. Reimplementing any part of it is out of scope for a menu bar spinner.

What was missing was the hand-off: the user had to leave the panel, find Activity
Monitor in Spotlight or Launchpad, and start over.

## Decision

Add a single control to the status panel's footer that launches (or focuses)
macOS's Activity Monitor.

- **Footer of the status face**, next to 終了 — the panel's existing row of
  "leaving now" actions. The front face is the one showing the readouts the user
  is reacting to, so the hand-off sits directly under them.
- **Icon only** (`chart.bar.xaxis`), with a `.help` tooltip and an
  `accessibilityLabel` carrying the full 「アクティビティモニタを開く」. The
  spelled-out label does not fit: at the panel's fixed 340-pt width, the version
  text plus a text-labelled button plus 終了 truncates the button (verified by
  rendering the footer offscreen, not by estimating).
- **Located once at launch, degrading to a disabled control.** `AppDelegate`
  resolves Activity Monitor at startup via `resolveActivityMonitorURL` — Launch
  Services first (`com.apple.ActivityMonitor`), falling back to
  `/System/Applications/Utilities/Activity Monitor.app` — and passes the panel a
  closure, or `nil` when neither probe finds it. `nil` disables the button and
  changes its tooltip to say why, instead of offering a button that silently does
  nothing. This mirrors the GPU degrade path (ADR 0001).
- **The popover closes before the launch**, and the launch activates Activity
  Monitor, so focus lands where the user is going rather than leaving a stale
  transient popover behind an app that just came forward.
- **The lookup is a pure function in `LoadSpinnerCore`.** Both probes are injected
  (`NSWorkspace`/`FileManager` in the app, stubs in tests), keeping the precedence
  rule and the not-found case unit-tested while the AppKit layer stays thin.

## Consequences

- One new pure function and its tests in `LoadSpinnerCore`; a thin
  `ActivityMonitor` wrapper over `NSWorkspace` in the app target; a closure
  threaded `AppDelegate` → `PanelContainer` → `PanelView`, alongside the existing
  `onQuit`.
- No new settings, no new permissions, no new sampling. Launching another app
  needs no entitlement, and Activity Monitor's own privileges are its business.
- The panel gains a second reason to exist beyond glancing — it is now also the
  route to the detailed view. The settings face is untouched.
- The footer is now three items wide. Anything further added there will need a
  different home, or the version text will have to give up room.

## Alternatives considered

- **A right-click `NSMenu` on the status item** (Activity Monitor / 設定 / 終了).
  One click closer, and a standard macOS idiom, but invisible: nothing on screen
  says a right-click does anything, so a control placed only there is a control
  most users never find. It also splits the status item's click handling in two.
  Not ruled out as a *future addition* — it would layer on top of this without
  changing it.
- **Making the CPU / GPU / memory cards clickable.** Elegant in principle (press
  the number you are worried about), but a card gives no affordance that it is
  pressable, so it needs hover styling and a hint to be discoverable at all — more
  UI than the button it replaces.
- **Showing the top processes in the panel itself.** The honest version of this is
  per-process sampling, a sortable table, and a kill action — Activity Monitor,
  rebuilt worse, in a 340-pt popover. A dishonest version (a static top-3 list) is
  the worst of both: not enough to act on, and enough to look like it should be.
- **Opening Activity Monitor by path with `open(1)` or `NSWorkspace.open(_:)`.**
  Works, but hard-codes a location the OS is free to move and gives no way to know
  in advance whether it will succeed. Launch Services answers both.
