# COSMOS v5 — AI Context

## Project

COSMOS Core v5.0 is a distributed robotic systems platform for CubeSats, UAVs, and ground stations.
Released v5.0.0 (2026-08-27). This workspace (`hsfl/cosmosv5`) is a flat repo containing 7 layer repos
as git submodules. Each layer is independently buildable; each layer's cmake chains to all layers below it.

Shell on this machine (viirs): **tcsh** — use backtick syntax (`` `nproc` ``), not `$(nproc)`.

---

## Layer Chain

```
thirdparty(-1) → kernel(0) → micro-agent(1) → simulator(2) → agent(3) → modules(4) → ground-station(5)
```

| Layer | Dir | Use when you need |
|------:|-----|-------------------|
| -1 | `thirdparty/` | json11, zlib, jpeg, png only |
|  0 | `kernel/` | math, time, JSON, serial — bare-metal safe, no network |
|  1 | `micro-agent/` | networking, file transfer, lightweight hardware drivers |
|  2 | `simulator/` | orbital mechanics, pure physics — no agent framework |
|  3 | `agent/` | full COSMOS: agents, physics, namespace, propagation |
|  4 | `modules/` | pluggable modules (file, websocket, packethandler, propagator) |
|  5 | `ground-station/` | ground station hardware drivers and agents |

---

## Clone and Build

### Selective submodule init (do NOT use --recurse-submodules)

```bash
git clone https://github.com/hsfl/cosmosv5.git
cd cosmosv5
./setup.sh agent          # init thirdparty+kernel+micro-agent+simulator+agent
./setup.sh all            # also includes resources (~21 MB physics data files)
```

`setup.bat` is the Windows equivalent. Resources are excluded by default (`update = none` in `.gitmodules`).

### Build

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/cosmos
cmake --build . -j`nproc`                         # all programs for top layer
cmake --build . --target propagatorv3 -j`nproc`   # specific target
cmake --install .                                  # also installs resources/ if present
```

To build only up to a specific layer (cmake auto-inits missing submodules below it):
```bash
cmake .. -DCOSMOS_TOP_LAYER=micro-agent
```

`CMAKE_INSTALL_PREFIX` is the root (e.g. `$HOME/cosmos`); binaries install to `$prefix/bin/`.
`COSMOS_SOURCE` must point to the workspace root (the dir containing all 7 layer subdirs).

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

**thirdparty:** `json11` `localzlib` `localjpeg` `localpng`

**kernel:** `CosmosMath` `CosmosSupport` `CosmosSlip` `CosmosPrint` `CosmosString` `CosmosJson`
`CosmosTime` `CosmosPacket` `CosmosChannel` `CosmosCheck` `CosmosDeviceDisk` `CosmosDeviceI2C`
`CosmosDeviceSerial`

**micro-agent:** `CosmosData` `CosmosNetwork` `CosmosLog` `CosmosTransferLib` `CosmosDeviceCpu`
`CosmosCssl` `CosmosDeviceArduino` `CosmosBBFctns` `CosmosPicLib`

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

---

## Open Issues

| # | Description | Layer |
|---|-------------|-------|
| #82 | Introduce `timebase.h` to fix `elapsedtime`→`timelib` layering violation | kernel |
| #83 | Merge `configCosmosKernel.h` into `configCosmos.h` | kernel |
| #84 | Replace `cssl_lib` with `serialclass` and eliminate `cssl_lib` | micro-agent |

---

## Reference Docs

| File | Purpose |
|------|---------|
| `README.md` | GitHub landing page / quick start |
| `cosmos_v5_library_hierarchy.md` | Full library, target, and program reference |
| `COSMOSV5_SUMMARY.md` | Migration history, architecture decisions, release notes |
| `COSMOSV5_WORKSPACE.md` | Workspace build and CMake details |
| `USE_IN_PROJECT.md` | External project integration guide |
