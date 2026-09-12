# COSMOSv5 Migration Summary

## What was done

The monolithic `cosmos-core` repository was split into seven independently versioned
repositories and migrated to GitHub under the `hsfl` organization. This is the
**COSMOS v5.0** release, the breaking architectural change listed in the cosmos-core
version table.

---

## Final Architecture: Flat Workspace

`hsfl/cosmosv5` is a **flat workspace** — a single repo that holds all 7 layer repos
plus a resources repo as top-level git submodules.

```
cosmosv5/
  thirdparty/      → hsfl/cosmosv5-thirdparty
  kernel/          → hsfl/cosmosv5-kernel
  micro-agent/     → hsfl/cosmosv5-micro-agent
  simulator/       → hsfl/cosmosv5-simulator
  agent/           → hsfl/cosmosv5-agent
  modules/         → hsfl/cosmosv5-modules
  ground-station/  → hsfl/cosmosv5-ground-station
  resources/       → hsfl/cosmosv5-resources  (update = none — opt-in only)
  CMakeLists.txt
  setup.sh / setup.bat
```

Each layer repo is independently clonable and buildable. The cmake system requires
`COSMOS_SOURCE` to point at the workspace root (the directory containing all 7
layer subdirectories).

### Architecture decision: flat workspace vs. nested deps

An intermediate approach was tried where each layer repo contained its direct lower
dependency as a nested `deps/` submodule (agent contained simulator, simulator
contained micro-agent, etc.). This produced duplicate checkout trees and was removed.
The flat workspace is simpler: one clone, one `COSMOS_SOURCE`, no duplication.

---

## GitHub Repositories

All repos are public under the `hsfl` organization, on branch `main`.

| Layer | Directory | GitHub Repo |
|------:|-----------|-------------|
| -1 | `thirdparty/` | [hsfl/cosmosv5-thirdparty](https://github.com/hsfl/cosmosv5-thirdparty) |
|  0 | `kernel/` | [hsfl/cosmosv5-kernel](https://github.com/hsfl/cosmosv5-kernel) |
|  1 | `micro-agent/` | [hsfl/cosmosv5-micro-agent](https://github.com/hsfl/cosmosv5-micro-agent) |
|  2 | `simulator/` | [hsfl/cosmosv5-simulator](https://github.com/hsfl/cosmosv5-simulator) |
|  3 | `agent/` | [hsfl/cosmosv5-agent](https://github.com/hsfl/cosmosv5-agent) |
|  4 | `modules/` | [hsfl/cosmosv5-modules](https://github.com/hsfl/cosmosv5-modules) |
|  5 | `ground-station/` | [hsfl/cosmosv5-ground-station](https://github.com/hsfl/cosmosv5-ground-station) |
| data | `resources/` | [hsfl/cosmosv5-resources](https://github.com/hsfl/cosmosv5-resources) |

Landing page: [hsfl/cosmosv5](https://github.com/hsfl/cosmosv5) — README and library
hierarchy doc.

### Local paths

All repos live under `/home2/pilger/cosmos/src/<dir>` with SSH remotes:
`git@github.com:hsfl/cosmosv5-<dir>.git`

The resources repo lives at `/home2/pilger/cosmos/src/cosmosv5-resources` (the
workspace submodule at `cosmosv5/resources/` points to it).

---

## Layer Dependency Chain

```
kernel → micro-agent → simulator → agent → modules → ground-station
                                                ↑
                                           thirdparty (jpeg, png — optional, upper layers only)
```

Each layer depends only on the layers below it. `json11` is bundled in `kernel`;
`zlib` is bundled in `micro-agent`. `thirdparty` provides only `localjpeg` and
`localpng`, included automatically at the `modules` level and above.

| Layer | Use when you need… |
|-------|-------------------|
| `kernel` | math, time, JSON (json11 bundled), serial — no network |
| `micro-agent` | networking, file transfer, hardware drivers (zlib bundled) |
| `simulator` | orbital mechanics, no agent framework |
| `agent` | full COSMOS: agents, physics, propagation |
| `modules` | pluggable modules (file, websocket, propagator); pulls in thirdparty (jpeg/png) |
| `ground-station` | ground station hardware and agents |
| `thirdparty` | localjpeg, localpng only — included automatically by modules and above |

---

## Building COSMOSv5

### Clone and initialize

Do **not** use `--recurse-submodules` — it would download all layers and resources
regardless of what you need. Instead use the setup script to initialize only the
layers required for your work:

```bash
git clone https://github.com/hsfl/cosmosv5.git
cd cosmosv5
./setup.sh agent          # kernel + micro-agent + simulator + agent  (no thirdparty needed)
./setup.sh modules        # adds thirdparty (jpeg/png) + modules
./setup.sh all            # full stack including resources (~21 MB physics data files)
```

`setup.bat` is the Windows equivalent. `thirdparty` is only initialized for
`modules`, `ground-station`, and `all` — it is not needed for `agent` and below.
The `resources` submodule is marked `update = none` and never initialized automatically.

Layer options for `setup.sh`: `kernel` | `micro-agent` | `simulator` | `agent` |
`modules` | `ground-station` | `all`

### Build

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/path/to/install
cmake --build . -j`nproc`                         # all programs for selected top layer
cmake --build . --target propagatorv3 -j`nproc`   # specific program
cmake --install .                                  # also installs resources/ if present
```

To build only programs up to a specific layer:

```bash
cmake .. -DCOSMOS_TOP_LAYER=micro-agent -DCMAKE_INSTALL_PREFIX=/path/to/install
```

Valid `COSMOS_TOP_LAYER` values: `kernel` | `micro-agent` | `simulator` | `agent` |
`modules` | `ground-station` (default: `ground-station`).

The cmake chain files auto-initialize any missing lower-layer submodules during
configure, so `git submodule update --init` for specific layers is also supported
without the setup script.

> Note: shell on the development machine (viirs) is tcsh — use backtick syntax
> (`` `nproc` ``), not `$(nproc)`.

---

## Using COSMOSv5 in an External Project

Add the workspace as a single submodule, point `COSMOS_SOURCE` at it, and include
the cmake chain file for whichever layer you need. The cmake chain file will
auto-initialize any missing lower-layer submodules during configure.

```bash
git submodule add https://github.com/hsfl/cosmosv5.git deps/cosmosv5
git submodule update --init deps/cosmosv5
cd deps/cosmosv5 && ./setup.sh agent && cd ../..
```

```cmake
set(COSMOS_SOURCE "${CMAKE_SOURCE_DIR}/deps/cosmosv5")
set(COSMOS_LIBS pthread)

# Replace "agent" with whichever top layer your project needs
include(${COSMOS_SOURCE}/agent/cmake/use_cosmos_from_source.cmake)

target_link_libraries(myapp CosmosAgent CosmosSimulator CosmosConvert ...)
```

---

## CMake System

Each layer exposes `cmake/use_cosmos_from_source.cmake`. The pattern in every file:

1. `get_filename_component(COSMOS_SOURCE_<LAYER> "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)`
   — resolves the layer's own root from wherever the file is included.
2. `if(DEFINED COSMOS_SOURCE)` — auto-initializes the lower-layer submodule if its
   `CMakeLists.txt` is absent (runs `git submodule update --init <lower-layer>`),
   then chains to it.
3. `FATAL_ERROR` if `COSMOS_SOURCE` is not set, or if auto-init fails.

`COSMOS_SOURCE` must point to the flat workspace root (the directory containing
`thirdparty/`, `kernel/`, etc.).

Each chain file sets `COSMOS_<LAYER>_INCLUDED TRUE` when it runs. The workspace
`CMakeLists.txt` uses these flags to conditionally add program subdirectories,
so only programs for initialized layers are built.

---

## Key Files

| File | Location | Purpose |
|------|----------|---------|
| `README.md` | `cosmosv5/` repo root | GitHub landing page |
| `cosmos_v5_library_hierarchy.md` | `cosmosv5/` repo root | Full library/target reference |
| `COSMOSV5_WORKSPACE.md` | `cosmosv5/` repo root | Workspace architecture and build instructions |
| `COSMOSV5_SUMMARY.md` | `cosmosv5/` repo root | This file |
| `CLAUDE.md` | `cosmosv5/` repo root | AI context file (auto-loaded by Claude Code) |
| `setup.sh` / `setup.bat` | `cosmosv5/` repo root | Selective layer submodule init scripts |
| `github_migration_plan.md` | `cosmos/src/` | Original migration plan (historical, not in repo) |

---

## Release History

| Version | Date | Notes |
|---------|------|-------|
| v5.0.0 | 2026-08-27 | Initial release of the seven-repository flat workspace architecture |

All 8 repos (`cosmosv5` + 7 layers) are tagged and have a published GitHub release at `v5.0.0`.

### Post-release changes (post v5.0.0, on `main`)

#### Resources submodule (`hsfl/cosmosv5-resources`)

A new `resources/` submodule was added to the workspace containing the minimal physics
data files required to run propagation programs:

- `general/egm2008_coef.txt` — EGM2008 gravitational model
- `general/pgm2000a_coef.txt` — PGM2000A gravitational model
- `general/iers_pm_dut_ls.txt` — IERS Earth orientation parameters
- `general/lnx1900.405` — JPL Development Ephemeris DE405
- `general/wmm_2005/2010/2015/2020.cof` — World Magnetic Model epochs
- `general/yalebsc.txt` — Yale Bright Star Catalog

The submodule is marked `update = none` and is **not** initialized by default.
Use `./setup.sh all` or `git -c submodule.resources.update=checkout submodule update --init resources` to get it. (Plain `git submodule update --init resources` is silently skipped because of `update = none`.)
`cmake --install` copies it to `${CMAKE_INSTALL_PREFIX}/resources/general/`.

#### Selective layer initialization (`setup.sh` / `setup.bat`)

`--recurse-submodules` is no longer recommended. The workspace now ships
`setup.sh` (Linux/macOS) and `setup.bat` (Windows) for initializing only the
layers you need. Example:

```bash
./setup.sh micro-agent    # fetches only thirdparty + kernel + micro-agent
./setup.sh agent          # fetches thirdparty through agent (most common)
./setup.sh all            # full stack including resources
```

#### `COSMOS_TOP_LAYER` cmake option

The workspace `CMakeLists.txt` now accepts `-DCOSMOS_TOP_LAYER=<layer>` to build
only programs up to the specified layer. Valid values: `kernel`, `micro-agent`,
`simulator`, `agent`, `modules`, `ground-station` (default: `ground-station`).

#### CMake chain file auto-initialization

Each layer's `use_cosmos_from_source.cmake` now automatically runs
`git submodule update --init <lower-layer>` if the lower layer is absent.
This means setting `COSMOS_SOURCE` and including a single chain file is sufficient
even on a shallow workspace clone — cmake fetches the required layers itself.

#### Thirdparty disentanglement (#85, #86, #87)

`json11` and `zlib` have been moved out of `thirdparty` and bundled directly into
the layers that need them, making `kernel` and `micro-agent` fully self-contained:

- **`json11`** (MIT license) bundled in `kernel/libraries/json11/`. `kernel` no
  longer chains to `thirdparty` at all.
- **`zlib`** (zlib license) bundled in `micro-agent/libraries/zlib/`. `micro-agent`
  no longer chains to `thirdparty`; sets `COSMOS_ZLIB_INCLUDE_DIR` for libpng.
- **`thirdparty`** now provides only `localjpeg` and `localpng`. It is included
  automatically by `modules` (the first layer that may need image codecs).
  `localpng` reads `COSMOS_ZLIB_INCLUDE_DIR` set by micro-agent's chain.
- **`setup.sh` / `setup.bat`** updated: `kernel`, `micro-agent`, `simulator`, and
  `agent` no longer initialize `thirdparty`. Only `modules`, `ground-station`, and
  `all` include it.

License notices for json11 (MIT) and zlib (zlib/libpng) are preserved in the
respective bundled header files.

#### Bug fixes (agent layer)

- **`physicsclass.cpp` / `physicslib.cpp`**: The PGM2000A branch of the gravity
  model loader called `fopen()` then immediately passed the result to `fscanf()`
  without checking for `nullptr`. If `pgm2000a_coef.txt` is absent this was
  undefined behavior. Added the same `fi==nullptr` guard that the EGM2008 branch
  already had.

- **`propagatorv3.cpp`**: Added an explicit resource-directory check at startup
  that prints a clear diagnostic and exits if the resources directory or gravity
  model file cannot be found, instead of failing silently during the first physics
  step.

### Post-tag fix included in v5.0.0

`EVENT_TYPE_EARTH (0x1240)` and `EVENT_TYPE_MOON (0x1280)` were found missing from
`kernel/libraries/support/cosmos-defs.h` (present in cosmos-core but not carried over
in the initial split). The fix was committed and the kernel `v5.0.0` tag was moved to
include it before the release was published.

---

## Open Issues

| # | Description | Layer / Repo |
|---|-------------|--------------|
| — | `wmm_2025.cof` not yet included in resources — simulations using dates after 2025-01-01 will fail to load the magnetic model | `cosmosv5-resources` |
| #82 | Introduce `timebase.h` to fix `elapsedtime`→`timelib` layering violation | `cosmosv5-kernel` |
| #83 | Merge `configCosmosKernel.h` into `configCosmos.h` | `cosmosv5-kernel` |
| #84 | Replace `cssl_lib` with `serialclass` and eliminate `cssl_lib` | `cosmosv5-micro-agent` |
