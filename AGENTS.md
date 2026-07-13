# AGENTS.md — load-spinner

## Summary

macOS menu bar app (util-series) showing CPU/GPU load as a spinning indicator
whose speed tracks load. Swift/SwiftUI + AppKit, darwin/arm64, macOS 13+.
Single binary also exposes a `doctor` CLI subcommand.

## Build & test

- `make build` — compiles release binary and assembles `dist/load-spinner.app`
  (Info.plist version injected from `git describe`). **Never** run `swift build`
  for release output; always use the Makefile.
- `make test` / `swift test` — runs `LoadSpinnerCoreTests`.
- `make run` — build and launch.

## Structure

```
Sources/
  LoadSpinnerCore/     Pure, testable logic (no AppKit UI)
    Metrics.swift        CPUTicks + cpuUsage(from:to:)
    Speed.swift          SpeedRange + rotationsPerMinute(forLoad:)
    CPUSampler.swift     CPUSampling protocol, MachCPUSampler, LoadMonitor
    Settings.swift       IndicatorShape/DisplayMode enums, AppSettings, palette
  load-spinner/        Executable (AppKit)
    Entry.swift          @main; CLI dispatch vs GUI bootstrap
    AppDelegate.swift    NSStatusItem, sampling timer, settings menu
    SpinnerView.swift    Layer-backed animated indicator (lineDashPhase)
    SettingsStore.swift  UserDefaults-backed AppSettings persistence
    Doctor.swift         `doctor` subcommand
    NSColor+Hex.swift    #RRGGBB parsing
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
  functions or behind the `CPUSampling` protocol (mocked in tests). The AppKit
  layer stays thin.
- **Version.** Injected into Info.plist by `make build`; read at runtime via
  `CFBundleShortVersionString`, falling back to `dev` outside a bundle.

## Roadmap

- Phase 2: GPU via IOKit `PerformanceStatistics` (auto-disable when the key is
  absent), GPU-only / both modes with per-source shape+color, SwiftUI click panel
  (live values + Swift Charts history), `SMAppService` login-item toggle.
- Phase 3: signing + notarization, zip distribution, Homebrew tap, umbrella
  submodule + catalog integration.
