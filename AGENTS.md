# AGENTS.md — load-spinner

## Summary

macOS menu bar app (util-series) showing CPU/GPU load as a spinning indicator
whose speed tracks load, plus memory as a filling **gauge** (a level, not a rate).
Swift/SwiftUI + AppKit, darwin/arm64, macOS 13+. Single binary also exposes a
`doctor` CLI subcommand.

## Build & test

- `make build` — compiles the release binary. **Never** run `swift build` for
  release output; always use the Makefile.
- `make build-app` — assembles `dist/load-spinner.app` (Info.plist version from
  `git describe`) and signs it with a Developer ID Application identity.
- `make package` — build-app, then notarize + staple (`nlink-jp-notary` keychain
  profile), and zip to `dist/load-spinner-v<version>-darwin-arm64.zip`.
- `make brew` — generate the Homebrew cask from the built zip into the local
  `nlink-jp/homebrew-tap` checkout (see `scripts/release-brew.mk`).
- `make test` / `swift test` — runs `LoadSpinnerCoreTests`.
- `make run` — `swift run` (debug).

Release signing/notarization uses the shared scripts under `scripts/` (vendored
from the org `.github` templates), same as the other util-series GUI apps.

## Structure

```
Sources/
  LoadSpinnerCore/     Pure, testable logic (no AppKit UI)
    Metrics.swift        CPUTicks + cpuUsage(from:to:)
    Speed.swift          SpeedRange + rotationsPerMinute(forLoad:)
    CPUSampler.swift     CPUSampling protocol, MachCPUSampler, LoadMonitor
    GPUSampler.swift     GPUSampling, gpuUtilization(fromPerformanceStatistics:), IOKitGPUSampler
    Memory.swift         MemorySnapshot + memoryReading(from:), memoryGaugeColorHex (fixed/gradient) + percent/GB helpers
    MemorySampler.swift  MemorySampling protocol, MachMemorySampler (host_statistics64 + sysctls)
    Indicator.swift      indicatorPlans(...) — mode+loads -> IndicatorPlan[], GPU degrade
    Gradient.swift       gradientColorHex(at:stops:) + load stops (teal->amber->coral) and memory stops (blue->green->orange->red)
    Settings.swift       IndicatorShape/DisplayMode/ColorMode enums, AppSettings, palette
  load-spinner/        Executable (AppKit + SwiftUI)
    Entry.swift          @main; CLI dispatch vs GUI bootstrap
    AppDelegate.swift    NSStatusItem, GPU probe, sampling timer, status popover
    SpinnerView.swift    Layer-backed indicators: spinner cells (lineDashPhase) + gauge cells (strokeEnd fill)
    AppModel.swift       ObservableObject: live loads, history, settings
    PanelContainer.swift Two-faced flip: PanelView (front) ⇄ SettingsView (back); Y-axis rotation + per-face height fit
    PanelView.swift      SwiftUI popover front face (status): live gauges, Swift Charts history, top-right gear + quit
    SettingsView.swift   SwiftUI popover back face (settings): mode/color/shape/memory/login, top-right chevron back
    SettingsStore.swift  UserDefaults-backed AppSettings persistence
    LoginItem.swift      SMAppService launch-at-login wrapper
    Doctor.swift         `doctor` subcommand
    NSColor+Hex.swift    #RRGGBB -> NSColor
    Color+Hex.swift      #RRGGBB -> SwiftUI Color
    Version.swift        appVersion from bundle Info.plist
Tests/LoadSpinnerCoreTests/
Resources/Info.plist.in  Bundle template (@VERSION@, @BUNDLE_ID@)
```

## Design notes / gotchas

- **Menu bar animation uses AppKit, not `MenuBarExtra`.** A `MenuBarExtra` label
  renders as a static image and does not animate smoothly. The indicator is an
  `NSStatusItem` with a layer-backed view; the frame is fixed and the lit segment
  travels via an animated `CAShapeLayer.lineDashPhase`. See
  `docs/adr/0001-menubar-animation-appkit.md`.
- **Swift 6 strict concurrency.** UI types are `@MainActor`; timers use the
  target/selector API (not `@Sendable` closures) to avoid capture errors. The
  status view lives for the app lifetime, so it has no `deinit` timer teardown.
- **Testability.** All non-trivial logic lives in `LoadSpinnerCore` as pure
  functions or behind the `CPUSampling`/`GPUSampling` protocols (mocked in tests).
  The AppKit/SwiftUI layer stays thin.
- **Panel is built lazily.** The `NSPopover`'s `NSHostingController` is created on
  open and released in `popoverDidClose`. This matters: an earlier version created
  it eagerly and a `TimelineView(.animation)` drove continuous full-panel layout
  even while closed (~12% CPU). The panel now uses a static load gauge (the menu
  bar carries the animation), and idle CPU is ~1%.
- **Status and settings are two faces of one flipping popover.** The click-to-open
  popover is a card: `PanelView` (status) on the front, `SettingsView` on the back,
  hosted by `PanelContainer`, which flips between them with a Y-axis
  `rotation3DEffect`. Splitting them kept the popover uncluttered after the memory
  settings block grew (see `docs/adr/0003-settings-on-popover-back.md`). Gotchas
  worth knowing:
  - **Both flip toggles are top-right and `.focusable(false)`.** The front's gear
    and the back's chevron share the corner so the control never moves; without
    `focusable(false)` the chevron grabs keyboard focus and draws a focus ring the
    instant the settings face appears.
  - **The back face is pre-rotated 180°** so it reads correctly at the end of the
    turn, and the two faces' opacity crossfades on a half-duration schedule (front
    out first half, back in after the midpoint) so neither is ever seen mirrored.
  - **Per-face height fit.** The popover height follows the visible face rather than
    padding the shorter status face to the settings height. Each face is measured at
    its natural size with `.fixedSize(vertical:)` + a `GeometryReader`/
    `PreferenceKey` (so the measurement is independent of the height the container is
    currently constrained to), and `.frame(height:)` animates between them with the
    flip. A tried-first *separate `NSWindow`* was dropped as disjoint — it appeared
    away from the menu bar and had to `NSApp.activate`; see the ADR's alternatives.
- **Transient dismissal relies on the app never being activated.** `NSPopover`'s
  `.transient` outside-click close silently breaks in an accessory (LSUIElement)
  app once the process has been activated — status-lens hit this after adding a
  settings window + `NSApp.activate`. load-spinner is unaffected *only because*
  nothing here activates the app: settings live on the popover's back face and
  there is no other window (audited 2026-08-06). If a separate window or any
  `NSApp.activate` call is ever introduced, port status-lens's
  `installPopoverClickMonitors` (global + local mouse-down monitors closing the
  popover; the local monitor must ignore the status item button's window) in the
  same change.
- **GPU degrade.** GPU availability is probed once at launch (`IOKitGPUSampler`).
  When unavailable, `indicatorPlans` drops GPU and the panel hides GPU modes.
- **Memory is a gauge, not a spinner.** Memory is a *level* (how full), so it
  fills a static ring (`strokeEnd`) instead of spinning; `SpinnerView.Spec.kind`
  distinguishes `.spinner(rpm:)` from `.gauge(fill:)`, and `step()` skips gauge
  cells. It is an independent `showMemory` toggle (orthogonal to `DisplayMode`) and
  always available (no degrade path). The ring fills with the used ratio; its color
  is a fixed accent or a used-ratio gradient (`memoryColorMode`, an independent
  reuse of `ColorMode`, default `gradient`). "Used" follows Activity Monitor (App +
  Wired + Compressed, minus purgeable), **not** `free` — free is near-zero on macOS
  because the OS caches into idle RAM. (Pressure-band coloring was tried and dropped
  as unintuitive.) See `docs/adr/0002-memory-as-filling-gauge.md`.
- **Color mode.** `ColorMode.gradient` colors the indicator/gauge by current load
  (`loadGradientColorHex`); the history chart deliberately keeps fixed CPU-green /
  GPU-blue lines so the two series stay distinguishable. The native SwiftUI
  `ColorPicker` was tried and dropped — it doesn't present from a menu bar
  accessory app; fixed mode uses an inline swatch row instead.
- **Version.** Injected into Info.plist by `make build`; read at runtime via
  `CFBundleShortVersionString`, falling back to `dev` outside a bundle.

## Roadmap

- Phase 3: signing + notarization, zip distribution, Homebrew tap, umbrella
  submodule + catalog integration.
