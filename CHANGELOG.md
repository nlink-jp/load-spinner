# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
follows semantic versioning once released.

## [Unreleased]

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

### Fixed

- Panel popover now sizes to its SwiftUI content (`sizingOptions`) instead of
  clipping the header; panel widened and settings rows tightened so nothing
  overflows horizontally.
- History chart uses a fixed 3-minute window with the newest sample anchored to
  the right edge, so the line scrolls in from the right instead of compressing as
  samples accumulate.
