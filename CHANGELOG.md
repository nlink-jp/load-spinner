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
