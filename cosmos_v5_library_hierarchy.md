# COSMOS v5 — Library Dependency Hierarchy

## 1. Overview

COSMOS v5.0 distributes its code across seven layer repositories plus a resources
repository and an optional thirdparty repository. All repos live as flat submodules
of the `hsfl/cosmosv5` workspace. Each layer is independently buildable and depends
only on layers below it in the chain.

**CMake strategy:** Each layer exposes `cmake/use_cosmos_from_source.cmake` which
chains to the layer below it. A project sets `COSMOS_SOURCE` to the workspace root
and includes the cmake file for the highest layer it needs. Missing lower-layer
submodules are auto-initialized at cmake configure time.

**Build chain:**
```
kernel → micro-agent → simulator → agent → modules → ground-station
                                                ↑
                                      thirdparty (jpeg, png — optional, modules and above)
```

`json11` is bundled in `kernel/libraries/json11/` (MIT license).
`zlib` is bundled in `micro-agent/libraries/zlib/` (zlib license).
`thirdparty` provides only `localjpeg` and `localpng`.

**Install prefix:** `~/cosmos` (default via `CMAKE_INSTALL_PREFIX`). Binaries
install to `$prefix/bin/`; resource files to `$prefix/resources/general/`.

---

## 2. Layer Hierarchy

```
                                                              ● GROUND-STATION
Layer 5 │ GROUND-STATION   gs232b_lib  ic9100_lib  kisslib  kisstnc_lib
        │ (hardware)        kpc9612p_lib  mixwtnc_lib  prkx2su_class  prkx2su_lib
        │                   ts2000_lib  unixgpio  usrp_lib  netradio
════════╪═══════════════════════════════════════════════════════════════════════
        │                            ┌─────────────────────────────────────────
        │                            │ THIRDPARTY (opt)  localjpeg  localpng
        │                            │ (pulled in by modules cmake chain)
        │                            └─────────────────────────────────────────
        │                                                     ● MODULES
Layer 4 │ MODULES           file_module  websocket_module
        │                   packethandler_module  node_propagator_module
════════╪═══════════════════════════════════════════════════════════════════════
        │                                                     ● AGENT
Layer 3 │ AGENT             agentclass  command_queue  scheduler  event  task
        │ (framework)       beacon  packethandler
        │                   transferclass  FileSender  UdpSender
        │                   acq_a35  gige_lib
        │
        │ PHYSICS           physicsclass  physicslib  simulatorclass
        │ (namespace-aware) physicsdef (header-only)
        │
        │ NAMESPACE         convertlib  enumlib  objlib  jsondef  jsonlib
════════╪═══════════════════════════════════════════════════════════════════════
        │                                                     ● SIMULATOR
Layer 2 │ SIMULATOR         nrlmsise-00  nrlmsise-00_data  controllib
        │ (pure physics)    jpleph  envi  ephemlib  geomag  demlib
        │                   constants (header-only)
════════╪═══════════════════════════════════════════════════════════════════════
        │                                                     ● MICRO-AGENT
Layer 1 │ MICRO-AGENT       datalib  socketlib  logger  transferlib
        │ (data/network)    devicecpu
        │                   cssl_lib  arduino_lib  bbFctns  pic_lib
        │                   zlib *(bundled)*
════════╪═══════════════════════════════════════════════════════════════════════
        │                                                     ● KERNEL
Layer 0 │ KERNEL            math/* (bytelib crclib mathlib matrix vector rotation)
        │ (primitives)      configCosmos  configCosmosKernel  cosmos-errno
        │                   cosmos-errclass  cosmos-defs  sliplib  print_utils
        │                   stringlib  elapsedtime  timelib  timeutils
        │                   jsonclass  jsonobject  jsonvalue  check  convertdef
        │                   ax25class  packetcomm  channellib
        │                   devicedisk  i2c  serialclass
        │                   json11 *(bundled)*
```

---

## 3. Repository Contents

### Layer -1 — `thirdparty/` *(optional, modules and above)*
No COSMOS dependencies. Provides image codec libraries only.
`json11` has moved to `kernel`; `zlib` has moved to `micro-agent`.

| Library | CMake target | Notes |
|---------|-------------|-------|
| jpeg | `localjpeg` | |
| png | `localpng` | Requires `COSMOS_ZLIB_INCLUDE_DIR` (set by micro-agent's cmake chain) |

**Programs:** none

> `thirdparty` is included automatically by `modules`' cmake chain. It is not
> needed for `kernel`, `micro-agent`, `simulator`, or `agent`.

---

### Layer 0 — `kernel/`
No dependency on `get_cosmosresources()`. No thirdparty dependency. Safe for bare
embedded targets. `json11` is bundled directly in `libraries/json11/` (MIT license).

**Bundled** (`libraries/json11/`): json11 (MIT license — copyright notice preserved)

**Math** (`libraries/math/`):
bytelib, crclib, mathlib, matrix, vector, rotation

**Support** (`libraries/support/`):
configCosmos, configCosmosKernel, cosmos-errno, cosmos-errclass, cosmos-defs,
sliplib, print_utils, stringlib, elapsedtime, timelib, timeutils,
jsonclass, jsonobject, jsonvalue, check, convertdef,
ax25class, packetcomm, channellib

> `convertdef.h` extended with Earth geometry constants (`REARTHM`, `REARTHKM`,
> `FLATTENING`, `FRATIO`, `FRATIO2`) — previously in `physicsdef.h` but needed
> by `convertlib` at agent layer.

**Devices** (`libraries/device/`):
devicedisk (`device/disk/`), i2c + i2c.cpp (`device/i2c/`), serialclass (`device/serial/`)

> `CosmosDeviceI2C` links `CosmosTime` — i2c.cpp uses `ElapsedTime`.

| CMake target | Libraries |
|---|---|
| `json11` | json11 *(bundled)* |
| CosmosMath | bytelib, crclib, mathlib, matrix, vector, rotation |
| CosmosSupport | configCosmos, configCosmosKernel, cosmos-errno, cosmos-errclass, cosmos-defs |
| CosmosSlip | sliplib |
| CosmosPrint | print_utils |
| CosmosString | stringlib, jsonobject, jsonvalue (links json11) |
| CosmosJson | jsonclass |
| CosmosTime | timelib, timeutils, elapsedtime |
| CosmosPacket | packetcomm, ax25class |
| CosmosChannel | channellib |
| CosmosCheck | check |
| CosmosDeviceDisk | devicedisk |
| CosmosDeviceI2C | i2c (links CosmosTime) |
| CosmosDeviceSerial | serialclass |

**Programs:** `programs/general/` — calc_transform, countdown, json2tab, mjd, serial_talk, tab2json
**Tests:** `programs/tests/` — check_check, crctest, filespeed, lsfittest, netspeed, netspeedd, serialPutData, serialSendChar, serial_setdtr, string_test, testdata, test_device_i2c, testmath1
**Unit tests:** channellib_ut, jsonclass_ut, packetcomm_ut, print_utils_ut, sliplib_ut, stringlib_ut, elapsedtime_ut, timelib_ut

---

### Layer 1 — `micro-agent/`
Adds data I/O, networking, and lightweight hardware drivers. No thirdparty
dependency. `zlib` is bundled directly in `libraries/zlib/` (zlib license).
Sets `COSMOS_ZLIB_INCLUDE_DIR` in its cmake chain for use by `localpng`.

**Bundled** (`libraries/zlib/`): zlib (zlib license — copyright notice preserved)

**Support** (`libraries/support/`):
datalib, socketlib, logger, transferlib

**Devices**:
devicecpu (`device/cpu/`), cssl_lib + bbFctns + pic_lib (`device/general/`),
arduino_lib (`device/arduino/`)

> Open issue #84: replace all `cssl_lib` uses with `serialclass` (kernel) and eliminate.

| CMake target | Libraries |
|---|---|
| `localzlib` | zlib *(bundled)* |
| CosmosData | datalib (links localzlib) |
| CosmosNetwork | socketlib |
| CosmosLog | logger |
| CosmosTransferLib | transferlib |
| CosmosDeviceCpu | devicecpu |
| CosmosCssl | cssl_lib |
| CosmosDeviceArduino | arduino_lib |
| CosmosBBFctns | bbFctns |
| CosmosPicLib | pic_lib |

**Programs:** `programs/general/` — i2ctalk, make_path, serial_listen
**Tests:** errortest, log_move_test, mathspeed
**Unit tests:** datalib_ut, logger_ut, socketlib_ut

---

### Layer 2 — `simulator/`
Pure physics/math — no COSMOS namespace, no agentclass. Requires resource files
(IERS EOP, WMM.COF, JPL ephemeris, DEM tiles) at runtime.

**Physics** (`libraries/physics/`):
nrlmsise-00, nrlmsise-00_data, controllib, constants (header-only)

**Support** (`libraries/support/`):
jpleph, envi, ephemlib, geomag, demlib, convertdef (header-only copy)

> `convertlib` and `enumlib` live in agent (Layer 3), not here — both need
> `jsondef.h`/`JSON_TYPE_*` constants at compile time.

| CMake target | Libraries |
|---|---|
| CosmosNrlmsise | nrlmsise-00, nrlmsise-00_data |
| CosmosControl | controllib |
| CosmosJpleph | jpleph |
| CosmosEnvi | envi |
| CosmosEphem | ephemlib |
| CosmosGeomag | geomag |
| CosmosDem | demlib |

**Unit tests:** ephemlib_ut, jpleph_ut

---

### Layer 3 — `agent/`
Full COSMOS namespace, physics simulation, agent framework. Primary development
layer for spacecraft software. Programs using physics/simulation live here.

**Physics** (`libraries/physics/`):
physicsdef (header-only), physicslib, physicsclass, simulatorclass

> `CosmosPhysics` links `CosmosEnum` — physicsclass.cpp uses the Enum class.
> Programs using `Physics::Simulator::` methods must explicitly link `CosmosSimulator`.

**Support** (`libraries/support/`):
convertlib, enumlib, objlib, jsondef, jsonlib, beacon, packethandler,
transferclass, FileSender, UdpSender

> `convertlib.cpp` uses `JSON_TYPE_*` from `jsondef.h` — cannot compile below namespace layer.

**Agent** (`libraries/agent/`):
task, event, agentclass, command_queue, scheduler

**Devices** (`libraries/device/general/`):
gige_lib, acq_a35

| CMake target | Libraries |
|---|---|
| CosmosCad | objlib |
| CosmosConvert | convertlib |
| CosmosEnum | enumlib |
| CosmosNamespace | jsondef, jsonlib |
| CosmosPhysicsLib | physicslib, physicsdef |
| CosmosPhysics | physicsclass (links CosmosEnum) |
| CosmosSimulator | simulatorclass |
| CosmosBeacon | beacon |
| CosmosPacketHandler | packethandler |
| CosmosTask | task |
| CosmosEvent | event |
| CosmosAgent | agentclass |
| CosmosCommand | command_queue |
| CosmosScheduler | scheduler |
| CosmosTransfer | transferclass |
| FileSenderImpl | FileSender, UdpSender |
| CosmosDeviceGige | gige_lib |
| CosmosDeviceAcq | acq_a35 |

**Programs:** `programs/general/` — archive, check_satnogs, command_generator, command_generator_remote, cosmos_size, cubesat2obj, devstruc_size, eci2lvlh, fast_contacts, fast_propagator, geoc2tle, get_contacts, get_contacts_tle, get_ground_contacts, gige_ffc, gige_list, gige_snap, initialize_time, julian, latest_file, list_namespace, netperf_listen, netperf_send, propagatorv2/v3/v4/vx, propagator_web_json, shift_solid_thermal, state2tle, targetsim, tle2state, udp_listen/request/send
**Agents:** `programs/agents/` — agent, agent_cpu, agent_data, agent_exec, agent_forward, agent_monitor, agent_propagator, agent_route, agent_time, agent_tunnel, agent_tunnel2
**Other agents:** `programs/agents/other/` — agent_arduino, agent_node, agent_physics
**Tests:** `programs/tests/` — agent_simple_request, attlvlh, gauss_jackson_test, geod2eci2geod, objread, observation_windows, poslvlh, string_float_test, targetstruc_tests, tle2orbit, tledump, tletest
**Unit tests:** convertlib_ut, jsondef_ut, jsonlib_ut, packethandler_ut, transferclass_ut, transferlib_ut, beacon_ut, agent_ut
**Integration tests:** file_it, file_it_helpers, integration_tests
**Skipped (gtest not installed):** test_coordinate_transformations, test_event_scheduler — guarded with `find_package(GTest QUIET)`

---

### Layer 4 — `modules/`
The four agent capability modules, extracted into their own repo so downstream
projects can take only the modules they need without pulling in all of agent's
transitive program dependencies. The modules cmake chain automatically includes
`thirdparty` (for `localjpeg` and `localpng`) after the agent chain.

**Libraries** (`libraries/module/`):
file_module, websocket_module, packethandler_module, node_propagator_module

| CMake target | Libraries |
|---|---|
| CosmosModule | file_module, websocket_module, packethandler_module, node_propagator_module |

**Programs:** `programs/agents/` — agent_file (only program that directly includes module headers)

---

### Layer 5 — `ground-station/`
Ground-station hardware drivers and programs. Depends on modules (and therefore
the full agent chain) for programs that use agentclass.

**Devices** (`libraries/device/general/`):
gs232b_lib, ic9100_lib, kisslib, kisstnc_lib, kpc9612p_lib, mixwtnc_lib,
prkx2su_class, prkx2su_lib, ts2000_lib, unixgpio, usrp_lib

**Devices** (`libraries/device/netradio/`):
netradio

| CMake target | Libraries |
|---|---|
| CosmosKiss | kisslib |
| CosmosGpio | unixgpio |
| CosmosKissTnc | kisstnc_lib |
| CosmosKpc9612p | kpc9612p_lib |
| CosmosMixwTnc | mixwtnc_lib |
| CosmosGs232b | gs232b_lib |
| CosmosTs2000 | ts2000_lib |
| CosmosIc9100 | ic9100_lib |
| CosmosPrkx2suClass | prkx2su_class |
| CosmosPrkx2su | prkx2su_lib |
| CosmosUsrp | usrp_lib |
| CosmosNetRadio | netradio |

**Programs:** `programs/general/` — track_sband ⚠ (pre-existing device API error: uses `.ant` instead of `->ant`; skipped in build)
**Agents:** `programs/agents/` — add_radio, agent_antenna, agent_control, agent_kpc9612p, agent_radio, ax25_recv, ic9100, kiss_recv, monitor_antenna, monitor_gs, agent_transmitter, agent_transmitter2, kiss_send, kpc9612p_recv, kpc9612p_send, track_sband_test

---

## 4. Dependency Matrix

Columns: T=thirdparty, K=kernel, M=micro-agent, S=simulator, A=agent, Mod=modules, G=ground-station

```
         K   M   S   A  Mod  G   T
K        —
M        ✓   —
S        ✓   ✓   —
A        ✓   ✓   ✓   —
Mod      ✓   ✓   ✓   ✓   —       ✓
G        ✓   ✓   ✓   ✓   ✓   —   ✓
T        —                           (jpeg/png only — no COSMOS deps)
```

`thirdparty` is pulled in by `modules` and `ground-station` for jpeg/png.
`kernel` and `micro-agent` have no thirdparty dependency (json11 and zlib are bundled).

---

## 5. Open Issues

| # | Change | Layer |
|---|--------|-------|
| #77 | Move enums from `enumlib`→`convertlib` dep into `jsondef.h` | agent |
| #78 | Move `nrlmsise-00` to `libraries/math/` or `libraries/atmos/` | simulator |
| #79 | Move `convert_test_gui/` out of `libraries/` | core |
| #80 | Rename/relocate `module/` → now resolved by `modules` repo | ✅ superseded |
| #82 | Introduce `timebase.h` to fix elapsedtime→timelib layering violation | kernel |
| #83 | Merge `configCosmosKernel.h` into `configCosmos.h` | kernel |
| #84 | Replace `cssl_lib` with `serialclass` and eliminate `cssl_lib` | micro-agent |
| #85 | ~~Bundle json11 in kernel; remove thirdparty as kernel dependency~~ | ✅ kernel |
| #86 | ~~Bundle zlib in micro-agent; remove thirdparty as micro-agent dependency~~ | ✅ micro-agent |
| #87 | ~~Reduce thirdparty to localjpeg+localpng only; update setup.sh~~ | ✅ thirdparty |
| — | `wmm_2025.cof` missing from resources — geomag fails for dates after 2025-01-01 | resources |

---

## 6. Key Architectural Decisions

- **9 repos total**: 7 layers + `thirdparty` (optional, upper layers only) + `resources` (physics data files, opt-in).
- **`modules` added between agent and ground-station** so the four capability modules are independently consumable without pulling in ground-station hardware deps.
- **`json11` bundled in kernel**: kernel has no external dependencies. json11 (MIT) lives in `kernel/libraries/json11/`. Copyright notice preserved.
- **`zlib` bundled in micro-agent**: micro-agent has no thirdparty dependency. zlib lives in `micro-agent/libraries/zlib/`. Sets `COSMOS_ZLIB_INCLUDE_DIR` for `localpng`.
- **`thirdparty` provides only jpeg/png**: included automatically by the `modules` cmake chain. Not needed for kernel, micro-agent, simulator, or agent.
- **Chain order**: simulator is BELOW agent. `physicsclass`/`simulatorclass` include `jsonlib.h` at the header level, so they must live above the namespace layer.
- **`convertlib` in agent**: `convertlib.cpp` uses `JSON_TYPE_*` from `jsondef.h` and implements `json_out_*` declared in `jsonlib.h`. Cannot compile below namespace.
- **Earth geometry constants** (`REARTHM` etc.) added to `convertdef.h` (kernel).
- **`CosmosPhysics` links `CosmosEnum`**: `physicsclass.cpp` uses the Enum class directly.
- **`CosmosSimulator` must be explicit**: programs calling `Physics::Simulator::` methods must list `CosmosSimulator` in `target_link_libraries` — it does not propagate automatically.
- **`CosmosDeviceI2C` links `CosmosTime`**: `i2c.cpp` uses `ElapsedTime` / `microsleep`.
- **`agent_file` → modules**: includes `file_module.h` so must live at or above modules layer.
- **Ground-station agents** (add_radio, agent_antenna, etc.) live in ground-station, not agent.
- **`agent_transmitter`/`transmitter2`** use `kisslib.h` → ground-station.
- **`track_sband` (general)**: pre-existing device API bug (`.ant` vs `->ant`); skipped.
- **gtest**: not installed on viirs; two tests skipped with `find_package(GTest QUIET)` guard.
- **Source files copied, not moved**: all source files copied from cosmos-core to the new repos at the v5.0 split.
- **Resources**: physics data files live in `hsfl/cosmosv5-resources` (`resources/` submodule, `update = none`). Required by simulator-layer programs at runtime. `cmake --install` deploys them to `$prefix/resources/general/`.
