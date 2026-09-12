# COSMOSv5 Workspace Architecture

## Structure

`hsfl/cosmosv5` is a **flat workspace** containing all 7 COSMOS layers plus a
resources submodule as git submodules:

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

Previously each layer repo contained its dependency as a nested `deps/` submodule
(agent contained simulator, simulator contained micro-agent, etc.), producing
duplicate checkout trees. That was removed. Each layer repo's cmake now requires
`COSMOS_SOURCE` to point at the workspace root.

---

## Cloning and Initializing

Do **not** use `git clone --recurse-submodules` — it would download all layers
and the resources submodule regardless of what you need. Instead clone the
workspace and use the setup script to initialize only the layers required:

```bash
git clone https://github.com/hsfl/cosmosv5.git
cd cosmosv5
./setup.sh agent          # thirdparty + kernel + micro-agent + simulator + agent
```

On Windows use `setup.bat` instead of `./setup.sh`.

### Layer options for setup.sh / setup.bat

| Argument | Submodules initialized |
|---|---|
| `kernel` | thirdparty, kernel |
| `micro-agent` | thirdparty, kernel, micro-agent |
| `simulator` | thirdparty, kernel, micro-agent, simulator |
| `agent` | thirdparty, kernel, micro-agent, simulator, agent  ← **recommended default** |
| `modules` | thirdparty … modules |
| `ground-station` | thirdparty … ground-station |
| `all` | everything including resources (~21 MB physics data files) |

You can also initialize submodules directly without the script:

```bash
git submodule update --init thirdparty kernel micro-agent
```

### Resources submodule

The `resources/` submodule (`hsfl/cosmosv5-resources`) contains the physics data
files needed to run propagation programs (gravitational models, JPL ephemeris,
IERS data, WMM). It is marked `update = none` in `.gitmodules` and is never
initialized automatically. To get it:

```bash
./setup.sh all
# or
git submodule update --init resources
```

After building, `cmake --install` copies `resources/general/` to
`${CMAKE_INSTALL_PREFIX}/resources/general/`. Programs locate resources via the
`COSMOS` or `COSMOSRESOURCES` environment variable, or the default
`/usr/local/cosmos/resources`.

> **Note:** `wmm_2020.cof` is not yet included in the resources repo. Simulations
> using dates after 2020-01-01 will fail to load the magnetic model.

---

## Building

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/path/to/install
cmake --build . -j`nproc`                              # all programs
cmake --build . --target propagatorv3 -j`nproc`        # specific program
cmake --install .
```

### Building only part of the stack

Pass `-DCOSMOS_TOP_LAYER=<layer>` to limit which layers are compiled and which
programs are built. Valid values: `kernel` | `micro-agent` | `simulator` | `agent` |
`modules` | `ground-station` (default: `ground-station`).

```bash
cmake .. -DCOSMOS_TOP_LAYER=micro-agent -DCMAKE_INSTALL_PREFIX=/path/to/install
```

Only programs from `kernel` and `micro-agent` will be built; simulator, agent, and
higher programs are skipped.

> Shell on the development machine (viirs) is **tcsh** — use backtick syntax
> (`` `nproc` ``), not `$(nproc)`.

---

## Using COSMOSv5 in an External Project

Add the workspace as a single submodule. Set `COSMOS_SOURCE` to its path and include
the cmake chain file for whichever layer you need. The cmake chain file automatically
initializes any missing lower-layer submodules during configure.

```bash
git submodule add https://github.com/hsfl/cosmosv5.git deps/cosmosv5
git submodule update --init deps/cosmosv5
cd deps/cosmosv5 && ./setup.sh agent && cd ../..
```

```cmake
set(COSMOS_SOURCE "${CMAKE_SOURCE_DIR}/deps/cosmosv5")
set(COSMOS_LIBS pthread)

# Replace "agent" with whichever top layer your project needs.
# The chain builds everything from thirdparty up to that layer automatically.
# Missing lower-layer submodules are auto-initialized during cmake configure.
include(${COSMOS_SOURCE}/agent/cmake/use_cosmos_from_source.cmake)

target_link_libraries(myapp CosmosAgent CosmosSimulator CosmosConvert ...)
```

### Layer reference

| Layer | Include this cmake chain file | Use when you need… |
|---|---|---|
| `kernel` | `kernel/cmake/use_cosmos_from_source.cmake` | math, time, JSON, serial — no network |
| `micro-agent` | `micro-agent/cmake/use_cosmos_from_source.cmake` | networking, file transfer, hardware drivers |
| `simulator` | `simulator/cmake/use_cosmos_from_source.cmake` | orbital mechanics, no agent framework |
| `agent` | `agent/cmake/use_cosmos_from_source.cmake` | full COSMOS: agents, physics, propagation |
| `modules` | `modules/cmake/use_cosmos_from_source.cmake` | pluggable modules (file, websocket, propagator) |
| `ground-station` | `ground-station/cmake/use_cosmos_from_source.cmake` | ground station hardware and agents |

---

## Key cmake behavior

- `COSMOS_SOURCE` must point to the workspace root (the directory containing
  `thirdparty/`, `kernel/`, etc.)
- Each layer's `cmake/use_cosmos_from_source.cmake`:
  - Sets `COSMOS_<LAYER>_INCLUDED TRUE`
  - Auto-initializes the lower-layer submodule if its `CMakeLists.txt` is absent
    (runs `git submodule update --init <lower-layer>` via `execute_process`)
  - Chains to the lower layer's cmake file
- The workspace `CMakeLists.txt` uses `COSMOS_<LAYER>_INCLUDED` flags to
  conditionally add program subdirectories — only initialized layers get programs built
- `CMAKE_INSTALL_PREFIX` is the install root (e.g. `~/cosmos`); binaries go to
  `$prefix/bin/`, resources to `$prefix/resources/`
- Shell on viirs is tcsh — use backtick syntax (`` `nproc` ``), not `$(nproc)`
