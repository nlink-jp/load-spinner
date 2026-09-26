# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
follows semantic versioning once released.

## [Unreleased]

### Fixed

- The release zip no longer carries AppleDouble (`._*`) entries: the app is
  zipped with `ditto --norsrc --noextattr`, so its signature survives unpacking
  with `unzip`. `make verify-release` refuses a zip that carries them.

## [0.5.4] - 2026-09-21

### Fixed

- **The menu bar icon's highlight blinked when the panel opened.** Clicking the
  icon to open the panel left it unhighlighted for a frame or three before the
  highlight came back, on every click on macOS 27. The panel was still being
  built when the mouse button came up, and macOS drops the pressed highlight at
  that moment and shows the open-panel highlight only once the panel is up. The
  hidden settings side of the panel is now built just after the panel opens,
  which halves the time opening takes; the highlight stays on. The first open
  after the app starts can still blink once.

## [0.5.3] - 2026-09-21

### Fixed

- **Clicking the menu bar icon again right after the panel closed did nothing.**
  The app asked macOS whether the panel was open, and macOS keeps answering
  "open" for about half a second after it has closed (measured on macOS 27.0),
  so the click was taken for "close it" and nothing happened. Clicking
  repeatedly could leave the panel shut for as long as you kept clicking. The
  app now keeps its own record of whether the panel is up, and a click a tenth
  of a second after the panel closed opens it again.

## [0.5.2] - 2026-09-20

### Fixed

- The panel stayed open after some outside clicks: clicking an empty stretch of
  the menu bar, or another app's non-activating panel, did not close it.
  `NSPopover`'s transient dismissal only reacted to clicks in windows that take
  activation (measured on macOS 27.0). Outside clicks are now watched with
  explicit global/local mouse-down monitors while the panel is shown. Clicking
  the menu bar icon still toggles the panel, and clicks inside it keep it open

## [0.5.1] - 2026-08-25

### Fixed

- Clicking a notification banner could start a second instance (two menu
  bar items, double polling): notificationd opens the app via
  LaunchServices by bundle identifier, and with more than one registered
  copy of the .app (dev build in `dist/`, `/Applications`) it may launch
  a different copy than the running one. The app is now single-instance
  at two layers: `LSMultipleInstancesProhibited` in Info.plist stops
  LaunchServices launches, and a startup guard exits with a stderr note
  when another instance is already running (covers direct binary exec
  and `open -n`)

## [0.5.0] - 2026-08-23

### Added

- A button in the status panel's footer that opens macOS's **Activity Monitor** —
  the hand-off from "how busy is it?" (what this app shows) to "busy with what?"
  (what it deliberately does not). Icon only, with a tooltip: the spelled-out
  label does not fit next to the version and 終了 at the panel's width. If
  Activity Monitor cannot be located, the button is disabled and says so rather
  than doing nothing. See
  [docs/en/adr/0004-activity-monitor-handoff.md](docs/en/adr/0004-activity-monitor-handoff.md).

## [0.4.0] - 2026-07-18

### Changed

- Settings moved off the click-to-open popover's front and onto its **back face**:
  the panel now flips over — status readout (live rings, memory donut, history
  chart) on the front, settings on the back. A gear in the top-right corner flips
  to settings; a chevron in the same corner flips back, so the toggle never moves.
  The popover's height fits whichever face is showing (the status face is no longer
  padded out to the taller settings height), animating between the two in step with
  the flip. Settings are grouped into インジケーター / メモリ / 全般 sections. No
  settings behavior changed — only their location. See
  [docs/en/adr/0003-settings-on-popover-back.md](docs/en/adr/0003-settings-on-popover-back.md).

## [0.3.1] - 2026-07-16

### Changed

- The memory gradient now uses its own four-stop mapping — blue (idle) → green
  (the healthy mid-range sweet spot, at 50%) → orange (75%) → red (full) — instead
  of reusing the CPU/GPU load gradient, which colored a perfectly healthy 50%
  usage amber. CPU/GPU keep the teal → amber → coral load gradient.

## [0.3.0] - 2026-07-15

### Added

- Memory monitoring, rendered as a filling **gauge** (a *level*) rather than a
  spinner (a *rate*): a ring that fills with the used ratio and does not move. See
  [docs/en/adr/0002-memory-as-filling-gauge.md](docs/en/adr/0002-memory-as-filling-gauge.md).
  - Menu bar: an optional memory gauge (toggle in the panel), reusing the circle /
    rounded-square frame but filling `strokeEnd` to the used ratio (static — it
    does not spin). Shape-only, like the CPU/GPU spinners.
  - Gauge color: a fixed accent, or a used-ratio gradient (teal → amber → coral)
    that warms as memory fills — the same color axis as CPU/GPU (independent
    setting), defaulting to gradient.
  - Panel: a memory donut (used % in the hole, used / total GB), shown regardless of
    the menu bar toggle, plus a third memory line (used ratio) on the history chart.
- `LoadSpinnerCore` memory logic, pure and tested: `memoryReading(from:)` derives
  Activity-Monitor-style *Memory Used* (App + Wired + Compressed, excluding
  purgeable) — deliberately not `free`, which is misleadingly near-zero on macOS —
  plus the fixed/gradient gauge-color mapping. Live counters come from
  `MachMemorySampler` (`host_statistics64` `HOST_VM_INFO64` + `hw.memsize`).

## [0.2.0] - 2026-07-13

### Added

- Load-linked color mode — instead of a fixed color, the indicator and the panel
  gauge shift color with load along a teal → amber → coral gradient, so color
  conveys the level while speed conveys the intensity. Toggle in the panel
  (単色 / 負荷連動).

### Changed

- The history chart now uses fixed, distinct colors (CPU green, GPU blue) with a
  legend, so the two lines stay distinguishable regardless of the color mode.

## [0.1.1] - 2026-07-13

### Added

- Application icon — a teal comet spinner ring on a dark rounded-rect plate,
  echoing the menu bar indicator. Generated by `scripts/gen-icon.swift` and built
  into the bundle via `scripts/make-icns.sh`.

## [0.1.0] - 2026-07-13

### Added

- Project scaffold: SwiftPM package, Makefile-driven `.app` bundling, MIT license,
  bilingual README, and RFP documents.
- `LoadSpinnerCore` library with pure, tested logic: CPU usage from Mach tick
  deltas, load→RPM speed mapping, and the persisted `AppSettings` model.
- CPU load monitoring via `host_statistics` (`HOST_CPU_LOAD_INFO`).
- Menu bar indicator (AppKit `NSStatusItem` + layer-backed view) that animates a
  lit segment travelling around a fixed circle or rounded square, at a speed
  proportional to CPU load.
- Menu to change display mode (max / CPU only), symbol shape, and color, persisted
  to `UserDefaults`.
- `load-spinner doctor` and `--version` CLI subcommands in the same binary.
- GPU utilization sampling via IOKit `IOAccelerator` `PerformanceStatistics`
  (`gpuUtilization(fromPerformanceStatistics:)` + `IOKitGPUSampler`), tolerant of
  the undocumented key being absent (returns nil → GPU display disabled). `doctor`
  now reports GPU availability.
- `indicatorPlans(...)` resolves which indicators to show for the current mode and
  loads, with graceful GPU degrade (GPU-only → CPU, both → CPU-only, max ignores GPU).
- All display modes wired up: max / CPU only / GPU only / both. In `both` mode two
  indicators sit side by side, each with its own shape and color.
- Click-to-open SwiftUI panel (`NSPopover`): live CPU/GPU load gauges, a ~3-minute
  history chart (Swift Charts), and inline settings (mode, per-source shape and
  color). Replaces the previous settings `NSMenu`. Built lazily so it does no work
  while closed.
- Launch-at-login toggle via `SMAppService`.
- Optional vertical `CPU` / `GPU` / `MAX` badges next to the menu bar indicators,
  toggled from the panel. Monochrome and inverted for the menu bar's light/dark
  appearance, with a small gap between the two indicators in `both` mode.
- Developer ID signed, notarized, and stapled `.app`, distributed as a
  `darwin-arm64` zip and installable via the `nlink-jp/homebrew-tap` cask.

### Fixed

- Panel popover now sizes to its SwiftUI content (`sizingOptions`) instead of
  clipping the header; panel widened and settings rows tightened so nothing
  overflows horizontally.
- History chart uses a fixed 3-minute window with the newest sample anchored to
  the right edge, so the line scrolls in from the right instead of compressing as
  samples accumulate.
