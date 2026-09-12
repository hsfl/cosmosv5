# COSMOS v5 — AI Context

## Project

COSMOS Core v5.0 is a distributed robotic systems platform for CubeSats, UAVs, and ground stations.
Released v5.0.0 (2026-08-27). This workspace (`hsfl/cosmosv5`) is a flat repo containing layer repos
as git submodules. Each layer is independently buildable; each layer's cmake chains to all layers below it.

Shell on this machine (viirs): **tcsh** — use backtick syntax (`` `nproc` ``), not `$(nproc)`.

---

## Layer Chain

```
kernel(0) → micro-agent(1) → simulator(2) → agent(3) → modules(4) → ground-station(5)
```

`thirdparty` is an optional upper-layer submodule providing `localjpeg` and `localpng`, needed only
by tools at the modules/ground-station level. It is no longer a foundational dependency.

- **`json11`** is folded directly into `kernel` (MIT license — include with copyright notice).
- **`zlib`** is folded directly into `micro-agent` (zlib license — include with copyright notice).
- **`jpeg`, `png`** remain in `thirdparty`, pulled in only when needed at upper layers.

| Layer | Dir | Use when you need |
|------:|-----|-------------------|
|  0 | `kernel/` | math, time, JSON, serial — bare-metal safe, no network; includes json11 |
|  1 | `micro-agent/` | networking, file transfer, lightweight hardware drivers; includes zlib |
|  2 | `simulator/` | orbital mechanics, pure physics — no agent framework |
|  3 | `agent/` | full COSMOS: agents, physics, namespace, propagation |
|  4 | `modules/` | pluggable modules (file, websocket, packethandler, propagator) |
|  5 | `ground-station/` | ground station hardware drivers and agents |
| opt | `thirdparty/` | localjpeg, localpng — upper-layer tools only |

---

## Target Platforms and Layer Ceilings

| Platform | Target layer | Notes |
|----------|-------------|-------|
| viirs (tcsh) | `ground-station` (full) | Complete dev environment |
| Ubuntu / WSL (bash) | `agent` or `modules` | Dev/test, no hardware drivers needed; use `$(nproc)` |
| Raspberry Pi | `micro-agent` or `agent` | Depends on whether physics/propagation is needed |
| macOS | `agent` or `modules` | Similar to WSL |
| Arduino + POSIX | `kernel` | Bare-metal safe; json11 included directly |

---

## Prerequisites (Ubuntu / WSL)

```bash
sudo apt update
sudo apt install -y git cmake build-essential
```

Tested on Ubuntu 26.04 LTS (Resolute). Additional packages may be required at higher layers
(e.g. serial port, USB, network libs for ground-station hardware drivers).

---

## Clone and Build

### Selective submodule init (do NOT use --recurse-submodules)

```bash
git clone https://github.com/hsfl/cosmosv5.git
cd cosmosv5
./setup.sh agent          # init kernel+micro-agent+simulator+agent
./setup.sh all            # also includes resources (~21 MB physics data files)
```

`setup.bat` is the Windows equivalent. Resources are excluded by default (`update = none` in `.gitmodules`).

### Build

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/cosmos
cmake --build . -j`nproc`                         # viirs (tcsh) — all programs for top layer
cmake --build . -j$(nproc)                        # Ubuntu/WSL (bash)
cmake --build . --target propagatorv3 -j`nproc`   # specific target (tcsh)
cmake --install .                                  # also installs resources/ if present
```

To build only up to a specific layer (cmake auto-inits missing submodules below it):
```bash
cmake .. -DCOSMOS_TOP_LAYER=micro-agent
```

Valid `COSMOS_TOP_LAYER` values: `kernel` | `micro-agent` | `simulator` | `agent` |
`modules` | `ground-station` (default: `ground-station`).

`CMAKE_INSTALL_PREFIX` is the root (e.g. `$HOME/cosmos`); binaries install to `$prefix/bin/`.
`COSMOS_SOURCE` must point to the workspace root (the dir containing all layer subdirs).

---

## Using in an External Project

```bash
git submodule add https://github.com/hsfl/cosmosv5.git deps/cosmosv5
git submodule update --init deps/cosmosv5
cd deps/cosmosv5 && ./setup.sh agent && cd ../..
```

```cmake
set(COSMOS_SOURCE "${CMAKE_SOURCE_DIR}/deps/cosmosv5")
set(COSMOS_LIBS pthread)
include(${COSMOS_SOURCE}/agent/cmake/use_cosmos_from_source.cmake)
target_link_libraries(myapp CosmosAgent CosmosSimulator CosmosConvert ...)
```

---

## CMake Targets by Layer

**kernel:** `CosmosMath` `CosmosSupport` `CosmosSlip` `CosmosPrint` `CosmosString` `CosmosJson`
`CosmosTime` `CosmosPacket` `CosmosChannel` `CosmosCheck` `CosmosDeviceDisk` `CosmosDeviceI2C`
`CosmosDeviceSerial` `json11` *(bundled)*

**micro-agent:** `CosmosData` `CosmosNetwork` `CosmosLog` `CosmosTransferLib` `CosmosDeviceCpu`
`CosmosCssl` `CosmosDeviceArduino` `CosmosBBFctns` `CosmosPicLib` `localzlib` *(bundled)*

**simulator:** `CosmosNrlmsise` `CosmosControl` `CosmosJpleph` `CosmosEnvi` `CosmosEphem`
`CosmosGeomag` `CosmosDem`

**agent:** `CosmosCad` `CosmosConvert` `CosmosEnum` `CosmosNamespace` `CosmosPhysicsLib`
`CosmosPhysics` `CosmosSimulator` `CosmosBeacon` `CosmosPacketHandler` `CosmosTask` `CosmosEvent`
`CosmosAgent` `CosmosCommand` `CosmosScheduler` `CosmosTransfer` `FileSenderImpl`
`CosmosDeviceGige` `CosmosDeviceAcq`

**modules:** `CosmosModule`

**ground-station:** `CosmosKiss` `CosmosGpio` `CosmosKissTnc` `CosmosKpc9612p` `CosmosMixwTnc`
`CosmosGs232b` `CosmosTs2000` `CosmosIc9100` `CosmosPrkx2suClass` `CosmosPrkx2su` `CosmosUsrp`
`CosmosNetRadio`

**thirdparty (optional):** `localjpeg` `localpng`

---

## Key Architectural Notes

- **`CosmosSimulator` does not propagate** — programs calling `Physics::Simulator::` must link it explicitly.
- **`convertlib` is in agent (layer 3)**, not simulator — it uses `JSON_TYPE_*` from `jsondef.h`.
- **`simulator` is below `agent`** — `physicsclass`/`simulatorclass` include `jsonlib.h` at the header level.
- **`CosmosPhysics` links `CosmosEnum`** — `physicsclass.cpp` uses the Enum class.
- **`CosmosDeviceI2C` links `CosmosTime`** — `i2c.cpp` uses `ElapsedTime`/`microsleep`.
- **Earth geometry constants** (`REARTHM`, `REARTHKM`, etc.) are in `convertdef.h` (kernel), not `physicsdef.h`.
- **`agent_file`** lives in modules layer (includes `file_module.h`).
- **`agent_transmitter`/`transmitter2`** live in ground-station (use `kisslib.h`).
- **gtest not installed** on viirs — two tests guarded with `find_package(GTest QUIET)`.
- **`track_sband` (general)** has a pre-existing device API bug (`.ant` vs `->ant`); skipped in build.
- **json11** is MIT licensed — copyright notice must be preserved when bundled in kernel.
- **zlib** is zlib licensed — copyright notice must be preserved when bundled in micro-agent.

---

## Open Issues

| # | Description | Layer |
|---|-------------|-------|
| — | `wmm_2025.cof` missing from resources — simulations after 2025-01-01 fail to load the magnetic model | `cosmosv5-resources` |
| — | GCC 15: `zlib`, `localjpeg`, `localpng` may need `#include <cstdint>` — will surface when building modules/ground-station (json11 already fixed) | `cosmosv5-thirdparty`, `cosmosv5-micro-agent` |
| #82 | Introduce `timebase.h` to fix `elapsedtime`→`timelib` layering violation | kernel |
| #83 | Merge `configCosmosKernel.h` into `configCosmos.h` | kernel |
| #84 | Replace `cssl_lib` with `serialclass` and eliminate `cssl_lib` | micro-agent |
| #85 | ~~Fold `json11` into kernel; remove `thirdparty` as kernel dependency~~ ✅ | kernel |
| #86 | ~~Fold `zlib` into micro-agent; remove `thirdparty` as micro-agent dependency~~ ✅ | micro-agent |
| #87 | ~~Reduce `thirdparty` to `localjpeg`+`localpng` only; update setup.sh~~ ✅ | thirdparty |

---

## Reference Docs

| File | Purpose |
|------|---------|
| `README.md` | GitHub landing page / quick start |
| `cosmos_v5_library_hierarchy.md` | Full library, target, and program reference |
| `COSMOSV5_SUMMARY.md` | Migration history, architecture decisions, release notes |
| `COSMOSV5_WORKSPACE.md` | Workspace build and CMake details |
| `USE_IN_PROJECT.md` | External project integration guide |
