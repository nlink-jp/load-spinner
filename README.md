# load-spinner

A macOS menu bar indicator that spins in proportion to system load. The busier
your machine, the faster a lit segment travels around the icon; when idle, it
turns slowly. It is meant for a felt sense of "how busy is it right now" — there
is no numeric readout in the menu bar by design.

> Japanese: [README.ja.md](README.ja.md)

## Status

Early development. Phase 1 (CPU monitoring + menu bar animation) is implemented;
GPU monitoring and the click-to-open panel (live values + history graph) are
planned for Phase 2. See [docs/en/load-spinner-rfp.md](docs/en/load-spinner-rfp.md).

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon (arm64)

## Build

Always build through the Makefile — it assembles a proper `.app` bundle under
`dist/` (never run `swift build` directly for release output).

```sh
make build     # -> dist/load-spinner.app
make test      # run the unit test suite
make run       # build and launch
make clean
```

## Usage

Launch `dist/load-spinner.app`. A spinning indicator appears in the menu bar.
Click it to open a menu where you can change:

- Display mode: max (higher of CPU/GPU) or CPU only *(GPU-related modes arrive in Phase 2)*
- Symbol: circle or square
- Color

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
- The menu bar icon is an AppKit `NSStatusItem` hosting a layer-backed view. The
  frame is fixed; a `CAShapeLayer`'s `lineDashPhase` is animated so a single lit
  segment travels around the perimeter. Rotation speed is mapped linearly from
  load (see [docs/adr/0001-menubar-animation-appkit.md](docs/adr/0001-menubar-animation-appkit.md)).

## License

MIT — see [LICENSE](LICENSE).
