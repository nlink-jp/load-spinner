# load-spinner

A macOS menu bar indicator that spins in proportion to system load. The busier
your machine, the faster a lit segment travels around the icon; when idle, it
turns slowly. It is meant for a felt sense of "how busy is it right now" — there
is no numeric readout in the menu bar by design.

> Japanese: [README.ja.md](README.ja.md)

## Status

In development. CPU and GPU monitoring, the animated menu bar indicator (one or
two frames), and the click-to-open panel (live gauges, history graph, settings)
are implemented. Remaining: signing/notarization and release
(Phase 3). See [docs/en/load-spinner-rfp.md](docs/en/load-spinner-rfp.md).

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
Click it to open a panel showing live CPU/GPU load, a recent history graph, and
settings:

- Display mode: max (higher of CPU/GPU), CPU only, GPU only, or both (two indicators)
- Symbol: circle or square — set per source (CPU and GPU independently in both mode)
- Color — a fixed per-source color, or a load-linked gradient (teal → amber → coral) that shifts with load
- Launch at login

When GPU utilization cannot be read on the system, GPU-related options are
disabled automatically and the app runs CPU-only. Settings persist across launches.

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
- The menu bar icon is an AppKit `NSStatusItem` hosting a layer-backed view. The
  frame is fixed; a `CAShapeLayer`'s `lineDashPhase` is animated so a single lit
  segment travels around the perimeter. Rotation speed is mapped linearly from
  load (see [docs/adr/0001-menubar-animation-appkit.md](docs/adr/0001-menubar-animation-appkit.md)).

## License

MIT — see [LICENSE](LICENSE).
