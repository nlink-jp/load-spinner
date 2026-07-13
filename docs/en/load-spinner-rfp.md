# RFP: load-spinner

> Generated: 2026-07-13
> Status: Draft

## 1. Problem Statement

While working on macOS, the user wants to sense CPU / GPU load intuitively rather than
by reading numbers. `load-spinner` lives in the menu bar and shows an indicator that
rotates (a lit segment travels around a frame) at a speed proportional to the load:
faster when load is high, slower when low, so the current state is graspable at a glance.
The target user is a developer / power user (initially the author). The primary goal is a
felt sense of "how busy is it right now," not precise numeric readings.

## 2. Functional Specification

### Commands / API Surface

Primarily a GUI app (menu bar resident), with a diagnostic CLI subcommand embedded in the
same binary (the org's GUI + CLI single-binary pattern).

- `load-spinner` (no args): launch the GUI as a menu bar resident
- `load-spinner doctor`: diagnose CPU / GPU metric availability. Reports CPU read results,
  the IOKit `PerformanceStatistics` key detection result for GPU, and the obtained
  utilization values; if GPU is unavailable, states the reason
- `load-spinner --version`: print the `git describe`-derived version

### Input / Output

- Input: system metrics (CPU: Mach kernel statistics, GPU: IOKit). User input is via the
  GUI only
- Output (GUI):
  - Menu bar: icon only (no numeric display). The frame (circle / square) is fixed while
    a lit segment travels along it. Travel speed is proportional to load (low = slow,
    high = fast)
  - Click-to-open panel: live display of current CPU / GPU values, a load history graph
    for a recent window (Swift Charts), and the settings UI, all on one surface
- Output (CLI): `doctor` prints human-readable text to stdout

### Display Modes

- `Max (combined)`: shows the higher of CPU and GPU in a single indicator. Shape and color
  are a single choice
- `CPU only`: a single CPU indicator
- `GPU only`: a single GPU indicator
- `Both`: CPU and GPU side by side. Shape (circle / square) and color are configurable
  **independently for each** (e.g. CPU = circle / blue, GPU = square / green)

### Configuration

- Settings persisted via `@AppStorage` (UserDefaults): display mode, symbol shape
  (CPU/GPU/combined), color (CPU/GPU/combined), login-item ON/OFF
- History graph data lives only in an in-memory ring buffer (e.g. last 3 min × 1 Hz ≈ 180
  points). No persistence across restarts
- Auto-start: login-item registration via `SMAppService`. A toggle is placed in the panel,
  default OFF

### External Dependencies

- No external APIs / services / credentials at all (all local system APIs)
- CPU: Mach `host_statistics64` (`HOST_CPU_LOAD_INFO`) / `host_processor_info`
  (`PROCESSOR_CPU_LOAD_INFO`)
- GPU: the `PerformanceStatistics` property dictionary of the IOKit `IOAccelerator` service
  (`"Device Utilization %"`, etc.)

## 3. Design Decisions

- **Language / framework**: Swift / SwiftUI. `MenuBarExtra(.window)` renders the menu bar
  resident + click panel in SwiftUI, with Swift Charts for the history graph. Same shape as
  the existing observability GUIs `active-lens-gui` / `claude-usage-lens-gui` /
  `quick-translate`
- **Target platform**: darwin/arm64 only
- **CPU metrics**: Mach kernel statistics (public API, no permissions, no root). Utilization
  computed from tick deltas between samples. Sampling 1–2×/sec
- **GPU metrics**: IOKit `PerformanceStatistics`. No public API exists, so this relies on a
  semi-private IOKit key. It is the proven approach used by iStat Menus / asitop / mactop,
  requiring no root or entitlement. However, key names are undocumented and may change
  across OS versions, so when the key is not found the GPU display is automatically disabled
  and the app continues with CPU only (degrade design)
- **Self-load restraint**: metric sampling is capped at 1–2×/sec and rotation rendering is
  delegated to Core Animation (GPU-composited) to stay lightweight
- **Complementarity**: adds a system-load axis to util-series' observability menu bar
  residents (`active-lens-gui` = activity time, `claude-usage-lens-gui` = tokens/cost)
- **Out of scope**:
  - Intel Mac / Windows / Linux (darwin/arm64 only)
  - Network transmission / telemetry
  - Persistent history storage (in-memory only)
  - Numeric (%) display in the menu bar (intentionally omitted; the goal is a felt sense)
  - Metrics other than CPU/GPU (memory, network, temperature, etc.)

## 4. Development Plan

### Phase 1: Core

- CPU utilization via Mach kernel statistics (pure-function, testable design)
- Menu bar resident (`MenuBarExtra`) and the traveling-segment animation (fixed frame, lit
  segment travels, speed proportional to load)
- `Max (combined)` / `CPU only` modes with circle/square symbol and color selection
- Unit tests (utilization computation, load→speed mapping)
- Review unit: independently reviewable (self-contained with CPU monitoring + base animation)

### Phase 2: Features

- GPU utilization via IOKit `PerformanceStatistics` and auto-disable on unavailability
  (degrade)
- `GPU only` / `Both` modes, per-source shape and color configuration
- Click panel: live current-value display + history graph (Swift Charts) + settings UI
- Settings persistence (`@AppStorage`), login-item toggle via `SMAppService`
- `load-spinner doctor` subcommand
- Review unit: splittable into GPU support / panel UI / persistence + auto-start

### Phase 3: Release

- README.md / README.ja.md, CHANGELOG.md
- Signing + notarization (Developer ID), `.app` distributed as zip
- Registration in the Homebrew tap (arm64 prebuilt-binary, signature preserved)
- Update umbrella submodule pointer, reflect in org profile / web-site catalog
- Run `check-org.sh` and confirm all green

## 5. Required API Scopes / Permissions

None (no external service integration).

- No special entitlements or TCC (privacy) permissions required. Both CPU (Mach) and GPU
  (IOKit) can be read locally without privilege
- `SMAppService` login-item registration completes through a user-facing toggle and needs no
  additional permission

## 6. Series Placement

Series: util-series

Reason: a resident GUI app that visualizes system metrics locally, in the same category as
util-series' observability GUIs (`active-lens-gui`, `claude-usage-lens-gui`). It involves no
external-service authentication and fits the util-series GUI pattern of local-only, single
binary, darwin/arm64.

## 7. External Platform Constraints

- **Non-public GPU utilization API**: macOS has no fully public API for GPU utilization; this
  relies on the non-public IOKit `PerformanceStatistics` key. Key names / presence may change
  across OS versions, so a degrade design that disables the GPU display when the key is not
  found is mandatory
- **macOS version requirement**: `MenuBarExtra` and `SMAppService` require macOS 13 (Ventura)
  or later. Minimum supported OS is macOS 13
- **Menu bar width**: `Both` mode occupies the width of two icons
- **Menu bar rendering constraints**: sampling frequency and rendering method (Core Animation
  compositing) must be chosen so the resident animation does not consume its own CPU

---

## Discussion Log

- Origin: evaluated the feasibility of a menu bar indicator that rotates according to CPU/GPU
  load (high load = fast spin, low load = slow spin). Confirmed technically feasible (menu bar
  resident = `NSStatusItem`/`MenuBarExtra`, CPU = Mach statistics, GPU = IOKit)
- Presented interactive demos iteratively and agreed on:
  - Mode switching (max / CPU only / GPU only / both)
  - Selectable symbol (circle / square), configurable color
  - In both mode, per-source shape and color; single choice in combined mode
  - The square does not rotate as a shape; instead the frame is fixed and the lit segment
    travels around it (circles behave the same way — the color travels)
- Additionally agreed on click behavior: open a panel consolidating a live current-value
  display + history graph + settings. No numeric menu bar display needed (felt sense is the
  goal)
- Decided to include GPU monitoring but to auto-disable the GPU display when values cannot be
  obtained
- UI direction is "modern and sharp," agreed via a panel mockup
- Naming: considered the -lens family (load-lens) but chose `load-spinner` for immediate
  clarity of purpose
- Decisions:
  - Auto-start: login-item registration via `SMAppService`, toggle in panel, default OFF
  - CLI embedding: `doctor` subcommand only (for GPU availability troubleshooting)
  - History: in-memory only (reset on restart)
- Series: agreed on util-series (same category as observability residents)
