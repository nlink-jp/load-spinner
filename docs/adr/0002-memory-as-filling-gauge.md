# ADR 0002: Memory is a filling gauge (a level), not a spinner (a rate)

- Status: Proposed
- Date: 2026-07-15

## Context

load-spinner today rests on a single abstraction: **normalized load (0...1) →
rotation speed (RPM)**. `rotationsPerMinute` (`Speed.swift`), `IndicatorPlan.load`
(`Indicator.swift`), and the travelling lit segment in `SpinnerView` all assume
that every indicator expresses a *rate* — "how busy is this right now" — as motion.

We want to add memory as a third indicator. But memory is not a rate. CPU and GPU
are **flow** quantities (a busy fraction over an interval); memory is a **stock**
quantity (how full the pool is at this instant). What a user wants from a memory
indicator is not "how fast" but "how much headroom is left" — an absolute level.

One fact about memory on macOS shapes the derivation: **"Free memory" is
misleading.** macOS deliberately fills otherwise-idle RAM with file cache, so
`free / total` reads near-zero even when the machine is healthy. The faithful "how
full" figure is the Activity-Monitor-style *used* memory:
`(App + Wired + Compressed) / physical`, derived from
`host_statistics64(HOST_VM_INFO64)` page counters.

macOS also exposes a memory *pressure* level
(`kern.memorystatus_vm_pressure_level` → normal / warning / critical). We
initially colored the gauge by it, but it proved unintuitive to users — "usage is
high yet pressure says normal, so it's fine" is a hard mental model — so color
follows the used ratio instead (see Alternatives).

## Decision

Introduce memory as a distinct visual kind — a **level gauge** — alongside the
existing **rate spinners**, establishing the visual language *things that spin are
rates; the thing that fills is a level*.

- **Fill = used ratio.** The gauge's stroke fills in proportion to the
  Activity-Monitor-style used ratio (0...1), a continuous absolute value.
- **Color = fixed accent or used-ratio gradient.** The gauge's color axis is the
  same two-way `ColorMode { fixed, gradient }` as the CPU/GPU spinners, but an
  independent `memoryColorMode` setting: a fixed accent, or a gradient that warms
  as the ring fills (cool when empty → warm when full). Default is `gradient`, so
  out of the box the color reinforces "how full" — the one thing a user reads off a
  memory gauge. (Pressure-band coloring was tried first and dropped as unintuitive;
  see Alternatives.)
- **Static, not animated.** The gauge does not participate in the animation timer.
  Its stillness is itself the message ("this is a water level, not a speed"). Fill
  changes ease smoothly over ~0.3s; there is no perpetual motion.
- **Independent toggle, not a display mode.** A new `showMemory` setting is
  orthogonal to `DisplayMode` (max / cpu / gpu / both). Memory is *additive*, not
  an alternative you pick instead of CPU — so it is a toggle, and `DisplayMode`'s
  combinatorics stay unchanged. When on, the ring renders to the right of the
  CPU/GPU indicators.
- **Reuse the frame vocabulary.** The gauge reuses the circle / rounded-square
  frame (`IndicatorShape`) so it sits visually with the spinners, but renders as a
  `strokeStart/strokeEnd` fill instead of a travelling dash.
- **No numeric readout in the menu bar.** The menu-bar gauge is shape-only, like
  the CPU/GPU spinners. A number beside a ~22px ring was prototyped and removed as
  too cramped to read (see Alternatives). The panel donut carries the percentage in
  its hole, where there is room for it.
- **Core stays pure and testable.** Add `MemorySnapshot` (raw page counters +
  physical total) and a pure `memoryReading(_:) -> MemoryReading` (used bytes/ratio),
  mirroring `cpuUsage` and `gpuUtilization(fromPerformanceStatistics:)`. A
  `MemorySampling` protocol wraps the `host_statistics64` read so the derivation is
  unit tested without touching the kernel.
- **Panel.** The SwiftUI panel shows memory as a proper donut: fill = used ratio,
  color per the memory color mode, centered percentage, and `used / total GB`
  beneath.

## Consequences

- `SpinnerView.Spec` gains a kind — spinner (driven by `rpm`) vs gauge (driven by a
  static `fill`) — and the animation `step()` loop skips gauge cells. This is the
  first time the menu bar view draws two paradigms.
- Memory is **always available** (unlike GPU), so it needs no degrade / fallback
  path — simpler than the GPU handling.
- `AppSettings` gains `showMemory` (default off) via the existing tolerant
  `decodeIfPresent` pattern; old persisted settings load unchanged.
- Memory gets its own `memoryColorMode` (reusing the `ColorMode { fixed, gradient }`
  enum, default `gradient`) plus a `memoryColorHex` accent, rather than sharing the
  spinners' global `colorMode` — so its color can be set independently. The gradient
  is driven by the used ratio (the spinners' by load), reusing `loadGradientColorHex`.
- Memory **is plotted on the 3-minute history line chart** as a third line (used
  ratio %, sharing the 0...100 axis), in a fixed color distinct from CPU-green and
  GPU-blue. `AppModel` gains a `memoryHistory` buffer alongside `cpuHistory` /
  `gpuHistory`, and the legend gains a memory chip. (The line moves slowly, but it
  makes leak/creep visible over the window.)
- New pure functions and mappings are covered by `LoadSpinnerCoreTests`
  (`memoryReading` derivation, `memoryGaugeColorHex` fixed/gradient mapping, tolerant
  decode of the new fields).

## Alternatives considered

- **Pressure-band coloring (green / amber / red from the kernel).** Shipped briefly
  as the gauge color plus a 正常 / 警告 / 逼迫 pill. It is macOS's authoritative
  headroom verdict and, being independent of the fill, could carry a second signal —
  but it proved unintuitive: a ring can be visibly full yet colored "normal," and
  "usage is high but pressure is low, so it's fine" is not how people read a gauge.
  Dropped end-to-end (color, pill, and the `kern.memorystatus_vm_pressure_level`
  read) in favor of the fixed / used-ratio-gradient axis, keeping the whole gauge
  usage-centric.
- **Pressure as the fill (a 3-step gauge).** Considered filling the ring to the
  pressure level rather than the used ratio. Rejected: pressure has only three
  bands, so the fill would jump coarsely and abandon the continuous "how full"
  reading that is the gauge's whole point.
- **Fold memory into `DisplayMode`.** Uniform with CPU/GPU, but explodes the mode
  matrix (max/cpu/gpu/both × memory) and misrepresents memory as an *alternative*
  to CPU rather than an *addition*. Rejected in favor of an independent toggle.
- **Animate the gauge (e.g. pulse under pressure).** Muddies the rate-vs-level
  language. Left out of the baseline; a critical-band alert pulse could be
  revisited separately.
- **Numeric readout beside the menu-bar ring.** Prototyped (a `memoryShowValue`
  toggle drawing "63%" next to the gauge), but a number beside a ~22px ring was too
  cramped to read, so it was removed. The panel donut carries the percentage in its
  hole instead.
