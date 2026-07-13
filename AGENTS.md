# AGENTS.md — load-spinner

## Summary

macOS menu bar app (util-series) showing CPU/GPU load as a spinning indicator
whose speed tracks load. Swift/SwiftUI + AppKit, darwin/arm64, macOS 13+.
Single binary also exposes a `doctor` CLI subcommand.

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
    Indicator.swift      indicatorPlans(...) — mode+loads -> IndicatorPlan[], GPU degrade
    Settings.swift       IndicatorShape/DisplayMode enums, AppSettings, palette
  load-spinner/        Executable (AppKit + SwiftUI)
    Entry.swift          @main; CLI dispatch vs GUI bootstrap
    AppDelegate.swift    NSStatusItem, GPU probe, sampling timer, popover
    SpinnerView.swift    Layer-backed animated indicator(s) (1-2 cells, lineDashPhase)
    AppModel.swift       ObservableObject: live loads, history, settings
    PanelView.swift      SwiftUI panel: live gauges, Swift Charts history, settings
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
- **GPU degrade.** GPU availability is probed once at launch (`IOKitGPUSampler`).
  When unavailable, `indicatorPlans` drops GPU and the panel hides GPU modes.
- **Version.** Injected into Info.plist by `make build`; read at runtime via
  `CFBundleShortVersionString`, falling back to `dev` outside a bundle.

## Roadmap

- Phase 3: signing + notarization, zip distribution, Homebrew tap, umbrella
  submodule + catalog integration.
