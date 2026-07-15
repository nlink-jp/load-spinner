# load-spinner

A macOS menu bar indicator that spins in proportion to system load. The busier
your machine, the faster a lit segment travels around the icon; when idle, it
turns slowly. It is meant for a felt sense of "how busy is it right now" — CPU
and GPU carry no numeric readout in the menu bar by design.

Memory is different in kind: it is a *level*, not a rate — you care how full the
pool is right now, not how fast it is changing. So it renders as a **filling
gauge** (a ring that fills with the used ratio) rather than a spinner. Things that
spin are rates; the thing that fills is a level.

> Japanese: [README.ja.md](README.ja.md)

## Status

In development. CPU, GPU, and memory monitoring, the menu bar indicators
(spinners for CPU/GPU, a filling gauge for memory), and the click-to-open panel
(live gauges, memory donut, history graph, settings) are implemented. Remaining:
signing/notarization and release (Phase 3). See
[docs/en/load-spinner-rfp.md](docs/en/load-spinner-rfp.md).

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon (arm64)

## Build

Always build through the Makefile (never run `swift build` directly for release
output).

```sh
make build       # compile the release binary
make build-app   # assemble the signed dist/load-spinner.app
make package     # build-app, notarize + staple, then zip for release
make test        # run the unit test suite
make run         # build and run (debug)
make clean
```

`make build-app` signs the bundle with a Developer ID Application identity;
`make package` additionally notarizes and staples it, then produces
`dist/load-spinner-v<version>-darwin-arm64.zip` for release.

## Usage

Launch `dist/load-spinner.app`. A spinning indicator appears in the menu bar.
Click it to open a panel showing live CPU/GPU load, a memory donut, a recent
history graph, and settings:

- Display mode: max (higher of CPU/GPU), CPU only, GPU only, or both (two indicators)
- Symbol: circle or square — set per source (CPU and GPU independently in both mode)
- Color — a fixed per-source color, or a load-linked gradient (teal → amber → coral) that shifts with load
- Memory: show a filling gauge in the menu bar and choose its frame (circle/square)
  and color — a fixed accent, or a used-ratio gradient with memory's own mapping
  (blue → green → orange → red): barely-used RAM reads "cold," the healthy
  mid-range sweet spot is green, and only the high range warms
- Launch at login

The panel always shows the memory donut — used percentage in the hole and used /
total GB — regardless of the menu bar toggle. When GPU utilization cannot be read
on the system, GPU-related options are disabled automatically and the app runs
CPU-only; memory is always available.
Settings persist across launches.

### CLI

The same binary exposes a diagnostic subcommand:

```sh
load-spinner doctor      # check whether CPU/GPU metrics can be read
load-spinner --version   # print the version
load-spinner --help      # usage
```

## How it works

- CPU load is read from the Mach kernel (`host_statistics`, `HOST_CPU_LOAD_INFO`) —
  a public API needing no elevated privileges.
- Memory is read from `host_statistics64` (`HOST_VM_INFO64`): the used ratio
  follows Activity Monitor's *Memory Used* (App + Wired + Compressed), **not**
  `free` — on macOS free memory is misleadingly near-zero because the OS fills
  idle RAM with file cache (see
  [docs/adr/0002-memory-as-filling-gauge.md](docs/adr/0002-memory-as-filling-gauge.md)).
- The menu bar icon is an AppKit `NSStatusItem` hosting a layer-backed view. For
  spinners the frame is fixed while a `CAShapeLayer`'s `lineDashPhase` is animated
  so a single lit segment travels around the perimeter, at a speed mapped linearly
  from load (see [docs/adr/0001-menubar-animation-appkit.md](docs/adr/0001-menubar-animation-appkit.md)).
  The memory gauge reuses the frame but fills its stroke (`strokeEnd`) to the used
  ratio and does not animate.

## License

MIT — see [LICENSE](LICENSE).
